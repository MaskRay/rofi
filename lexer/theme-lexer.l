%option noyywrap nounput never-interactive
%option bison-locations

%{
#include <stdio.h>


#include "lexer/theme-parser.h"
int last_state = 0;
GQueue *queue = NULL;

%}
%{

int str_len = 0;
char      *input_str = NULL;

#define YY_INPUT(buf,result,max_size) \
{\
    if ( input_str == NULL ) { \
        errno =0; \
        while ( (result = (int) fread(buf, 1, max_size, yyin))==0 && ferror(yyin)) \
        { \
            if( errno != EINTR) \
            { \
                YY_FATAL_ERROR( "input in flex scanner failed" ); \
                break; \
            } \
            errno=0; \
            clearerr(yyin); \
        } \
    } else {\
        yy_size_t len = MIN (max_size, str_len);\
        if ( len > 0 ){\
            memcpy (buf, input_str, len);\
            input_str+=len;\
            str_len-=len;\
            result = len;\
        } else {\
            result = YY_NULL;\
        } \
    }\
}


#define YY_USER_ACTION {\
    yylloc->last_column+= yyleng;\
}
#define YY_LLOC_START {\
    yylloc->first_line = yylloc->last_line;\
    yylloc->first_column = yylloc->last_column;\
}
%}
WHITESPACE [[:blank:]]
WORD       [[:alnum:]-]+
STRING     [[:print:]]+
HEX        [[:xdigit:]]
NUMBER     [[:digit:]]
REAL       [[:digit:]]+(\.[[:digit:]]+)?
PX         (px)
EM         (em)
PERCENT    (\%)

ASTERIX    \*

CENTER     "center"
NORTH      "north"
SOUTH      "south"
EAST       "east"
WEST       "west"

NONE        "none"
BOLD        "bold"
UNDERLINE   "underline"
ITALIC      "italic"

LS_DASH    "dash"
LS_SOLID   "solid"

%x PROPERTIES
%x NAMESTR
%x ENTRY
%x DEFAULTS
%%

%{
YY_LLOC_START
%}
%{
if ( queue == NULL ){
    queue = g_queue_new ( );
}
%}

<*>"//"            {
    int c;
    while ((c = input()) != EOF){
        if (c == '\n') {
            yylloc->last_column = 1;
            yylloc->last_line ++;
            break;
        }
        yylloc->last_column++;
    }
    YY_LLOC_START
}
<*>"/*"            {
    int c = 0, p;
    int nesting_depth = 1;
    while (nesting_depth) {
        p = c;
        c = input();
        switch (c) {
        case '*': yylloc->last_column++; if (p == '/') { c = 0; nesting_depth++; } break;
        case '/': yylloc->last_column++; if (p == '*') { c = 0; nesting_depth--; } break;
        case '\n':  {
            yylloc->last_column = 1;
            yylloc->last_line ++;
            break;
        }
        case EOF: nesting_depth = 0; break;
        default:
            yylloc->last_column++;
        ;
        }
    }
    YY_LLOC_START
}

<INITIAL>{ASTERIX} {
    g_queue_push_head ( queue, GINT_TO_POINTER (YY_START) );
    BEGIN(DEFAULTS);
    return PDEFAULTS;
}
<DEFAULTS>{WHITESPACE} {}
<DEFAULTS>"\{"   {
    g_queue_push_head ( queue, GINT_TO_POINTER (YY_START) );
    BEGIN(ENTRY);
    return BOPEN;
}

  /* Go into parsing an entry */
<NAMESTR>"\{"                    {
    g_queue_push_head ( queue, GINT_TO_POINTER (YY_START) );
    BEGIN(ENTRY);
    return BOPEN;
}
  /* Pop out of parsing an entry. */
<ENTRY>"\}"             {
    g_queue_pop_head ( queue );
    BEGIN(GPOINTER_TO_INT(g_queue_pop_head ( queue )));
    return BCLOSE;
}

<INITIAL>"#"            { g_queue_push_head ( queue, GINT_TO_POINTER (YY_START) ); BEGIN(NAMESTR);return NAME_PREFIX;}
<NAMESTR>\.|{WHITESPACE}    { return NSEP; }
<ENTRY>{WORD}   { yylval->sval = g_strdup(yytext); return N_STRING;}
<NAMESTR>{WORD}         { yylval->sval = g_strdup(yytext); return NAME_ELEMENT;}

    /* After Namestr/Classstr we want to go to state str, then to  { */
   /*<NAMESTR>{WHITESPACE}   { BEGIN(GPOINTER_TO_INT (g_queue_pop_head ( queue )));}*/
<INITIAL,ENTRY>{WHITESPACE}+	; // ignore all whitespace
<PROPERTIES>{WHITESPACE}+	; // ignore all whitespace

<INITIAL,ENTRY>":"               { g_queue_push_head ( queue, GINT_TO_POINTER (YY_START) ); BEGIN(PROPERTIES); return PSEP; }
<PROPERTIES>";"                  { BEGIN(GPOINTER_TO_INT ( g_queue_pop_head ( queue ))); return PCLOSE;}
<PROPERTIES>(true|false)         { yylval->bval= g_strcmp0(yytext, "true") == 0; return T_BOOLEAN;}
<PROPERTIES>{NUMBER}+            { yylval->ival = (int)g_ascii_strtoll(yytext, NULL, 10); return T_INT;}
<PROPERTIES>{NUMBER}+\.{NUMBER}+ { yylval->fval = g_ascii_strtod(yytext, NULL); return T_DOUBLE;}
<PROPERTIES>\"{STRING}\"         { yytext[yyleng-1] = '\0'; yylval->sval = g_strdup(&yytext[1]); return T_STRING;}
<PROPERTIES>@{WORD}              {
    yylval->sval = g_strdup(yytext);
    return T_LINK;
}

<PROPERTIES>{REAL}{EM}        {
    yylval->distance.distance = (double)g_ascii_strtod(yytext, NULL);
    yylval->distance.type     = PW_EM;
    yylval->distance.style    = SOLID;
    return T_PIXEL;
}
<PROPERTIES>{NUMBER}+{PX}        {
    yylval->distance.distance = (double)g_ascii_strtoll(yytext, NULL, 10);
    yylval->distance.type     = PW_PX;
    yylval->distance.style    = SOLID;
    return T_PIXEL;
}
<PROPERTIES>{NUMBER}+{PX}{WHITESPACE}{LS_DASH} {
    yylval->distance.distance = (double)g_ascii_strtoll(yytext, NULL, 10);
    yylval->distance.type     = PW_PX;
    yylval->distance.style    = DASH;
    return T_PIXEL;
}
<PROPERTIES>{NUMBER}+{EM}{WHITESPACE}{LS_DASH} {
    yylval->distance.distance = (double)g_ascii_strtoll(yytext, NULL, 10);
    yylval->distance.type     = PW_PX;
    yylval->distance.style    = DASH;
    return T_PIXEL;
}
<PROPERTIES>{NUMBER}+{PX}{WHITESPACE}{LS_SOLID} {
    yylval->distance.distance = (double)g_ascii_strtoll(yytext, NULL, 10);
    yylval->distance.type     = PW_PX;
    yylval->distance.style    = SOLID;
    return T_PIXEL;
}
<PROPERTIES>{NUMBER}+{EM}{WHITESPACE}{LS_SOLID} {
    yylval->distance.distance = (double)g_ascii_strtoll(yytext, NULL, 10);
    yylval->distance.type     = PW_PX;
    yylval->distance.style    = SOLID;
    return T_PIXEL;
}
<PROPERTIES>{REAL}{PERCENT}        {
    yylval->distance.distance = (double)g_ascii_strtod(yytext, NULL);
    yylval->distance.type     = PW_PERCENT;
    yylval->distance.style    = SOLID;
    return T_PIXEL;
}
<PROPERTIES>{REAL}{PERCENT}{WHITESPACE}{LS_SOLID}        {
    yylval->distance.distance = (double)g_ascii_strtod(yytext, NULL);
    yylval->distance.type     = PW_PERCENT;
    yylval->distance.style    = SOLID;
    return T_PIXEL;
}
<PROPERTIES>{REAL}{PERCENT}{WHITESPACE}{LS_DASH}        {
    yylval->distance.distance = (double)g_ascii_strtod(yytext, NULL);
    yylval->distance.type     = PW_PERCENT;
    yylval->distance.style    = DASH;
    return T_PIXEL;
}
<PROPERTIES>#{HEX}{8}       {
    union {  unsigned int val; struct { unsigned char b,g,r,a;};} val;
    val.val = (unsigned int)strtoull ( &yytext[1], NULL, 16);
    yylval->colorval.alpha = val.a/255.0;
    yylval->colorval.red   = val.r/255.0;
    yylval->colorval.green = val.g/255.0;
    yylval->colorval.blue  = val.b/255.0;
    return T_COLOR;
}
<PROPERTIES>argb:{HEX}{8}       {
    union {  unsigned int val; struct { unsigned char b,g,r,a;};} val;
    val.val = (unsigned int)strtoull ( &yytext[1], NULL, 16);
    yylval->colorval.alpha = val.a/255.0;
    yylval->colorval.red   = val.r/255.0;
    yylval->colorval.green = val.g/255.0;
    yylval->colorval.blue  = val.b/255.0;
    return T_COLOR;
}
<PROPERTIES>#{HEX}{6}       {
    union {  unsigned int val; struct { unsigned char b,g,r,a;};} val;
    val.val = (unsigned int)g_ascii_strtoull ( &yytext[1], NULL, 16);
    yylval->colorval.alpha = 1.0;
    yylval->colorval.red   = val.r/255.0;
    yylval->colorval.green = val.g/255.0;
    yylval->colorval.blue  = val.b/255.0;
    return T_COLOR;
}
<PROPERTIES>rgba\({NUMBER}{1,3},{NUMBER}{1,3},{NUMBER}{1,3},[01](\.{NUMBER}+)?\) {
    char *endptr = &yytext[5];
    yylval->colorval.red = g_ascii_strtoull ( endptr, &endptr, 10);
    yylval->colorval.green= g_ascii_strtoull ( endptr+1, &endptr, 10);
    yylval->colorval.blue= g_ascii_strtoull ( endptr+1, &endptr, 10);
    yylval->colorval.alpha= g_ascii_strtod ( endptr+1, NULL);
    return T_COLOR;
}
<PROPERTIES>rgb\({NUMBER}{1,3},{NUMBER}{1,3},{NUMBER}{1,3}\) {
    char *endptr = &yytext[4];
    yylval->colorval.red   = g_ascii_strtoull ( endptr, &endptr, 10);
    yylval->colorval.green = g_ascii_strtoull ( endptr+1, &endptr, 10);
    yylval->colorval.blue  = g_ascii_strtoull ( endptr+1, &endptr, 10);
    yylval->colorval.alpha = 1.0;
    return T_COLOR;
}

<PROPERTIES>{CENTER} {
    yylval->ival = WL_CENTER;
    return T_POSITION;
}
<PROPERTIES>{EAST} {
    yylval->ival = WL_EAST;
    return T_POSITION;
}
<PROPERTIES>{WEST} {
    yylval->ival = WL_WEST;
    return T_POSITION;
}
<PROPERTIES>{SOUTH}{EAST} {
    yylval->ival = WL_SOUTH_EAST;
    return T_POSITION;
}
<PROPERTIES>{SOUTH}{WEST} {
    yylval->ival = WL_SOUTH_WEST;
    return T_POSITION;
}
<PROPERTIES>{SOUTH} {
    yylval->ival = WL_SOUTH;
    return T_POSITION;
}
<PROPERTIES>{NORTH}{EAST} {
    yylval->ival = WL_NORTH_EAST;
    return T_POSITION;
}
<PROPERTIES>{NORTH}{WEST} {
    yylval->ival = WL_NORTH_WEST;
    return T_POSITION;
}
<PROPERTIES>{NORTH} {
    yylval->ival = WL_NORTH;
    return T_POSITION;
}
<PROPERTIES>{NONE} {
    yylval->ival = HL_NONE;
    return T_HIGHLIGHT_STYLE;
}
<PROPERTIES>{BOLD} {
    yylval->ival = HL_BOLD;
    return T_HIGHLIGHT_STYLE;
}
<PROPERTIES>{ITALIC} {
    yylval->ival = HL_ITALIC;
    return T_HIGHLIGHT_STYLE;
}
<PROPERTIES>{UNDERLINE} {
    yylval->ival = HL_UNDERLINE;
    return T_HIGHLIGHT_STYLE;
}
<INITIAL><<EOF>>  {
    g_queue_free ( queue );
    // Reset pointer to NULL
    queue = NULL;
    yyterminate();
}

<*>\n {
        yylloc->last_column = 1;
        yylloc->last_line ++;
};
<*>(\r\n) {
        yylloc->last_column = 1;
        yylloc->last_line ++;
};
<INITIAL>. {
    return T_ERROR;
}
<*>. {
    fprintf(stderr, "Invalid character: '%c'\n", *yytext);
    return T_ERROR;
}

%%
