# Custom kitten: show/hide/toggle the tab bar of the OS window containing the
# target kitty window, at runtime. Kitty's remote-control protocol has no
# builtin command for this (tab_bar_hidden is only ever set once, at startup,
# from tab_bar_style == "hidden" - see kitty/tabs.py), so this pokes the
# internal (undocumented) TabManager API directly, which is the sanctioned
# escape hatch custom kittens have for anything not exposed over `kitten @`.
#
# Driven from nvim (nvim/lua/utils/fullscreen.lua) so zen mode can hide the
# tab bar on <leader>uz and restore it on exit:
#   kitten @ kitten toggle_tab_bar.py hide
#   kitten @ kitten toggle_tab_bar.py show
from kitty.boss import Boss
from kittens.tui.handler import result_handler


def main(args: list[str]) -> str:
    pass


@result_handler(no_ui=True)
def handle_result(args: list[str], answer: str, target_window_id: int, boss: Boss) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    tab = w.tabref()
    if tab is None:
        return
    tm = tab.tab_manager_ref()
    if tm is None:
        return
    action = args[0] if args else "toggle"
    if action == "hide":
        tm.tab_bar_hidden = True
    elif action == "show":
        tm.tab_bar_hidden = False
    else:
        tm.tab_bar_hidden = not tm.tab_bar_hidden
    # resize() only calls layout_tab_bar() (which marks the bar dirty for
    # repaint) when the bar is NOT hidden, so hiding it would otherwise
    # change the flag without ever triggering a redraw. Mark it dirty
    # ourselves so both directions repaint immediately.
    tm.mark_tab_bar_dirty()
    tm.resize()
