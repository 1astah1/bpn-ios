#!/usr/bin/env python3
"""Концепты экранов через Seedream 4.5 (ключ BytePlus Умки). Образцы стиля — кадр баннера «Включи BPN» и логотип.
Картинки — только направление для вёрстки; текст на них проверять не стоит.
Запуск: python3 design/gen_concepts.py [имя ...] → ~/bpn-ios-design/concepts/<имя>.jpg (готовые не перегенерируются)."""
import base64
import concurrent.futures as cf
import json
import os
import pathlib
import sys
import time
import urllib.request

URL = "https://ark.ap-southeast.bytepluses.com/api/v3/images/generations"
KEY = open(os.path.expanduser("~/.config/umka/byteplus.key")).read().strip()
OUT = pathlib.Path.home() / "bpn-ios-design" / "concepts"
REFS = [pathlib.Path(p).expanduser() for p in os.environ.get("REFS", "").split(":") if p]
SIZE = "1440x2560"

BIBLE = (
    " Premium iOS app screen shown inside one clean modern iPhone mockup with a thin dark titanium frame, centered with even"
    " margins on a plain very dark charcoal backdrop, the screen content is the hero."
    " Visual style exactly like the reference banner: deep near-black navy background #0E1116 with faint dotted grid texture"
    " and soft film grain, glass capsules with thin luminous royal-blue borders #2F6BFF, royal blue #0052B4 gradients,"
    " soft blue glow, small monospace uppercase labels in light blue starting with //, big bold geometric sans numbers in"
    " off-white, tiny green status dots, dotted elliptical orbit lines with small dark pill chips of city codes."
    " The brand mark is the cream-white 3D hexagon with a blue wifi symbol from the reference logo, rendered as a glossy"
    " tactile 3D object. Clean controlled palette: near-black, royal blue, cream white, one small green accent."
    " One single continuous screen, no split, no panels, no collage. Sharp readable typography, generous spacing,"
    " no clutter, no fake charts, no purple."
)

P = {
    "a-toggle": "Home screen of a VPN app. Centerpiece: a huge vertical glass toggle capsule in the middle of the screen,"
                " the cream 3D hexagon wifi knob sits at the top of the capsule in ON position with a strong blue glow"
                " filling the capsule below it, the word ON in bold white inside the capsule. Around the capsule a dotted"
                " elliptical orbit with five small pill chips: AMS, FRA, HEL 41 ms, STO, PRG, each with a green dot."
                " Above: small monospace label // ПОДКЛЮЧЕНО and big title Чехия. Bottom: one slim glass strip with three"
                " big numbers 364 дн, 18 ГБ, 41 мс and tiny labels. Minimal top bar with a small gear icon.",
    "b-orbit": "Home screen of a VPN app built like a radar. Center: a large glossy cream 3D hexagon wifi button floating"
               " over concentric dotted orbit rings, small flag nodes sit on the rings, one node (Finland) is linked to the"
               " hexagon by a glowing royal-blue arc line. Under the hexagon big bold text 00:12:48 connection timer and"
               " monospace label // ЗАЩИЩЕНО. Bottom: a docked dark glass bottom sheet with the selected server row:"
               " round flag, Финляндия, 38 мс, a chevron, and a thin signal bar. Very airy, lots of dark space.",
    "c-console": "Home screen of a VPN app designed like a premium hardware console. Top half: big status headline in bold"
                 " off-white «Вы под защитой» with monospace label // AUTO · 9 СЕРВЕРОВ, below it a route diagram: a small"
                 " dot labeled Вы, a dotted line going through a glowing node labeled Германия to a globe glyph, with"
                 " small latency numbers. Bottom third in the thumb zone: a wide horizontal glass toggle capsule exactly"
                 " like the reference banner: ON label on the left, the cream 3D hexagon wifi knob on the right with blue"
                 " glow. Between them a compact strip with two stats: Осталось 364 дн and Трафик 18 ГБ.",
}


def data_uri(path: pathlib.Path) -> str:
    mime = "image/png" if path.suffix == ".png" else "image/jpeg"
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode()


def gen(name: str) -> str:
    out = OUT / f"{name}.jpg"
    if out.exists():
        return f"{name}: уже есть"
    payload = {"model": "seedream-4-5-251128", "prompt": P[name] + BIBLE, "size": SIZE,
               "response_format": "url", "watermark": False}
    if REFS:
        payload["image"] = [data_uri(p) for p in REFS]
    body = json.dumps(payload).encode()
    err = ""
    for attempt in range(3):
        try:
            req = urllib.request.Request(URL, data=body, headers={"Authorization": f"Bearer {KEY}",
                                                                   "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=300) as r:
                data = json.loads(r.read())
            if "data" not in data:
                raise RuntimeError(json.dumps(data)[:300])
            urllib.request.urlretrieve(data["data"][0]["url"], out)
            return f"{name}: ok"
        except Exception as e:  # сеть, очередь — пробуем ещё раз
            err = str(e)[:300]
            time.sleep(5 * (attempt + 1))
    return f"{name}: ОШИБКА {err}"


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or list(P)
    with cf.ThreadPoolExecutor(4) as ex:
        for line in ex.map(gen, names):
            print(line, flush=True)
