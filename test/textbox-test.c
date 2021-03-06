#include <unistd.h>
#include <stdlib.h>

#include <stdio.h>
#include <assert.h>
#include <glib.h>
#include <history.h>
#include <string.h>
#include <xcb/xcb.h>
#include <widgets/textbox.h>
#include <rofi.h>
#include <cairo-xlib.h>
#include "settings.h"

static int   test               = 0;
unsigned int normal_window_mode = 0;

#define TASSERT( a )    {                                 \
        assert ( a );                                     \
        printf ( "Test %3i passed (%s)\n", ++test, # a ); \
}

#include "view.h"
void rofi_view_queue_redraw ()
{
}
void rofi_view_get_current_monitor ( int *width, int *height )
{

}
int rofi_view_error_dialog ( const char *msg, G_GNUC_UNUSED int markup )
{
    fputs ( msg, stderr );
    return FALSE;
}

int abe_test_action ( G_GNUC_UNUSED KeyBindingAction action, G_GNUC_UNUSED unsigned int mask, G_GNUC_UNUSED xkb_keysym_t key )
{
    return FALSE;
}
int show_error_message ( const char *msg, int markup )
{
    rofi_view_error_dialog ( msg, markup );
    return 0;
}

int main ( G_GNUC_UNUSED int argc, G_GNUC_UNUSED char **argv )
{
    cairo_surface_t *surf = cairo_image_surface_create ( CAIRO_FORMAT_ARGB32, 100, 100 );
    cairo_t         *draw = cairo_create ( surf );
    PangoContext    *p    = pango_cairo_create_context ( draw );
    textbox_set_pango_context ( p );

    textbox *box = textbox_create ( "textbox", TB_EDITABLE | TB_AUTOWIDTH | TB_AUTOHEIGHT, NORMAL, "test" );
    TASSERT ( box != NULL );

    textbox_keybinding ( box, MOVE_END );
    TASSERT ( box->cursor == 4 );
    textbox_cursor ( box, -1 );
    TASSERT ( box->cursor == 0 );
    textbox_cursor ( box, 8 );
    TASSERT ( box->cursor == 4 );
    textbox_cursor ( box, 2 );
    TASSERT ( box->cursor == 2 );
    textbox_insert ( box, 3, "bo", 2 );
    TASSERT ( strcmp ( box->text, "tesbot" ) == 0 );
    textbox_keybinding ( box, MOVE_END );
    TASSERT ( box->cursor == 6 );

    TASSERT ( widget_get_width ( WIDGET ( box ) ) > 0 );
    TASSERT ( textbox_get_height ( box ) > 0 );

    TASSERT ( widget_get_width ( WIDGET ( box ) ) >= textbox_get_font_width ( box )  );
    TASSERT ( textbox_get_height ( box ) >= textbox_get_font_height ( box )  );

    TASSERT ( textbox_get_estimated_char_width ( ) > 0 );

    textbox_keybinding ( box, REMOVE_CHAR_BACK );
    TASSERT ( strcmp ( box->text, "tesbo" ) == 0 );
    TASSERT ( box->cursor == 5 );

    textbox_keybinding ( box, MOVE_CHAR_BACK );
    TASSERT ( box->cursor == 4 );
    textbox_keybinding ( box, REMOVE_CHAR_FORWARD );
    TASSERT ( strcmp ( box->text, "tesb" ) == 0 );
    textbox_keybinding ( box, MOVE_CHAR_BACK );
    TASSERT ( box->cursor == 3 );
    textbox_keybinding ( box, MOVE_CHAR_FORWARD );
    TASSERT ( box->cursor == 4 );
    textbox_keybinding ( box, MOVE_CHAR_FORWARD );
    TASSERT ( box->cursor == 4 );
    // Cursor after delete section.
    textbox_delete ( box, 0, 1 );
    TASSERT ( strcmp ( box->text, "esb" ) == 0 );
    TASSERT ( box->cursor == 3 );
    // Cursor before delete.
    textbox_text ( box, "aap noot mies" );
    TASSERT ( strcmp ( box->text, "aap noot mies" ) == 0 );
    textbox_cursor ( box, 3 );
    TASSERT ( box->cursor == 3 );
    textbox_delete ( box, 3, 6 );
    TASSERT ( strcmp ( box->text, "aapmies" ) == 0 );
    TASSERT ( box->cursor == 3 );

    // Cursor within delete
    textbox_text ( box, "aap noot mies" );
    TASSERT ( strcmp ( box->text, "aap noot mies" ) == 0 );
    textbox_cursor ( box, 5 );
    TASSERT ( box->cursor == 5 );
    textbox_delete ( box, 3, 6 );
    TASSERT ( strcmp ( box->text, "aapmies" ) == 0 );
    TASSERT ( box->cursor == 3 );
    // Cursor after delete.
    textbox_text ( box, "aap noot mies" );
    TASSERT ( strcmp ( box->text, "aap noot mies" ) == 0 );
    textbox_cursor ( box, 11 );
    TASSERT ( box->cursor == 11 );
    textbox_delete ( box, 3, 6 );
    TASSERT ( strcmp ( box->text, "aapmies" ) == 0 );
    TASSERT ( box->cursor == 5 );

    textbox_text ( box, "aap noot mies" );
    textbox_cursor ( box, 8 );
    textbox_keybinding ( box, REMOVE_WORD_BACK );
    TASSERT ( box->cursor == 4 );
    TASSERT (  strcmp ( box->text, "aap  mies" ) == 0 );
    textbox_keybinding ( box, REMOVE_TO_EOL );
    TASSERT ( box->cursor == 4 );
    TASSERT (  strcmp ( box->text, "aap " ) == 0 );
    textbox_text ( box, "aap noot mies" );
    textbox_cursor ( box, 8 );
    textbox_keybinding ( box, REMOVE_WORD_FORWARD );
    TASSERT (  strcmp ( box->text, "aap noot" ) == 0 );
    textbox_keybinding ( box, MOVE_FRONT );
    TASSERT ( box->cursor == 0 );
    textbox_keybinding ( box, CLEAR_LINE );
    TASSERT (  strcmp ( box->text, "" ) == 0 );
    textbox_text ( box, "aap noot mies" );
    textbox_keybinding ( box, MOVE_END );
    textbox_keybinding ( box, MOVE_WORD_BACK );
    TASSERT ( box->cursor == 9 );
    textbox_keybinding ( box, MOVE_WORD_BACK );
    TASSERT ( box->cursor == 4 );
    textbox_keybinding ( box, REMOVE_TO_SOL );
    TASSERT (  strcmp ( box->text, "noot mies" ) == 0 );
    TASSERT ( box->cursor == 0 );

    textbox_font ( box, HIGHLIGHT );
    //textbox_draw ( box, draw );

    widget_move ( WIDGET ( box ), 12, 13 );
    TASSERT ( box->widget.x == 12 );
    TASSERT ( box->widget.y == 13 );

    widget_free ( WIDGET ( box ) );
    textbox_cleanup ( );
}
