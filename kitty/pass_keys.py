import re

from kittens.tui.handler import result_handler
from kitty.key_encoding import KeyEvent, parse_shortcut


def is_passthrough(window, app_id):
    # True when the focused window's foreground program matches app_id (a regex,
    # checked against each foreground process name). For those programs the key
    # is forwarded into the child instead of moving between kitty windows: nvim
    # gets its split-nav, fzf gets list movement (Ctrl-j/k = down/up).
    fp = window.child.foreground_processes
    return any(re.search(app_id, p['cmdline'][0] if len(p['cmdline']) else '', re.I) for p in fp)


def encode_key_mapping(window, key_mapping):
    mods, key = parse_shortcut(key_mapping)
    event = KeyEvent(
        mods=mods,
        key=key,
        shift=bool(mods & 1),
        alt=bool(mods & 2),
        ctrl=bool(mods & 4),
        super=bool(mods & 8),
        hyper=bool(mods & 16),
        meta=bool(mods & 32),
    ).as_window_system_event()

    return window.encoded_key(event)


def main():
    pass


@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    direction = args[1]
    key_mapping = args[2]
    # Default matches nvim AND fzf: pass the key through to either; for anything
    # else fall through to kitty window navigation. Override per-binding by
    # passing a 4th arg in kitty.conf.
    app_id = args[3] if len(args) > 3 else "n?vim|fzf"

    window = boss.window_id_map.get(target_window_id)

    if window is None:
        return
    if is_passthrough(window, app_id):
        for keymap in key_mapping.split(">"):
            encoded = encode_key_mapping(window, keymap)
            window.write_to_child(encoded)
    else:
        boss.active_tab.neighboring_window(direction)
