#!/usr/bin/env python3
"""Telegram bot for FI VPN server status, reboot, and torrent blocker (@Vpn_Sharpmaind_bot)."""

from __future__ import annotations

import html
import json
import logging
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

from telegram import BotCommand, InlineKeyboardButton, InlineKeyboardMarkup, Update
from telegram.ext import Application, CallbackQueryHandler, CommandHandler, ContextTypes

logging.basicConfig(
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    level=logging.INFO,
)
log = logging.getLogger("vpn-bot")

BOT_TOKEN = os.environ.get("BOT_TOKEN", "").strip()
ALLOWED_CHAT_IDS = {
    int(x.strip())
    for x in os.environ.get("ALLOWED_CHAT_IDS", "").split(",")
    if x.strip().isdigit()
}

FI_IP = "193.124.224.248"

REMNAWAVE_BASE_URL = os.environ.get(
    "REMNAWAVE_BASE_URL", "https://vpn2.sharpmaind.ru"
).rstrip("/")
REMNAWAVE_API_TOKEN = os.environ.get("REMNAWAVE_API_TOKEN", "").strip()
REMNAWAVE_PLUGIN_UUID = os.environ.get("REMNAWAVE_PLUGIN_UUID", "").strip()
REMNAWAVE_NODE_UUID = os.environ.get("REMNAWAVE_NODE_UUID", "").strip()
REMNAWAVE_PROFILE_UUID = os.environ.get("REMNAWAVE_PROFILE_UUID", "").strip()
REMNAWAVE_BLOCK_DURATION = int(os.environ.get("REMNAWAVE_BLOCK_DURATION", "3600"))

BT_BLOCK_RULE = {"protocol": ["bittorrent"], "outboundTag": "BLOCK"}

HELP_TEXT = """SharpVpn Ops Bot

/status — состояние FI сервера
/torrent — срез bittorrent on/off (без бана IP)
/reboot — перезагрузка FI (Финляндия)
/myid — ваш chat_id

Перезагрузка требует подтверждения кнопкой."""


def icon(ok: bool) -> str:
    return "✅" if ok else "❌"


def esc(text: str) -> str:
    return html.escape(text, quote=False)


def run_local(cmd: list[str], timeout: int = 30) -> tuple[int, str]:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        return proc.returncode, out.strip()
    except subprocess.TimeoutExpired:
        return 124, "timeout"
    except Exception as exc:
        return 1, str(exc)


def is_allowed(update: Update) -> bool:
    if not ALLOWED_CHAT_IDS:
        return False
    chat_id = update.effective_chat.id if update.effective_chat else None
    user_id = update.effective_user.id if update.effective_user else None
    return chat_id in ALLOWED_CHAT_IDS or user_id in ALLOWED_CHAT_IDS


async def deny(update: Update) -> None:
    chat_id = update.effective_chat.id if update.effective_chat else "?"
    text = (
        f"Доступ запрещён.\n"
        f"Ваш chat_id: <code>{esc(str(chat_id))}</code>\n\n"
        "Добавьте его в ALLOWED_CHAT_IDS на сервере и перезапустите бота."
    )
    if update.message:
        await update.message.reply_text(text, parse_mode="HTML")
    elif update.callback_query:
        await update.callback_query.answer("Доступ запрещён", show_alert=True)


def format_uptime(raw: str) -> str:
    raw = raw.strip()
    m = re.search(r"up\s+(.+?),\s*\d+\s+user", raw)
    if m:
        return m.group(1).strip()
    m = re.search(r"up\s+(.+)", raw)
    return m.group(1).split(",")[0].strip() if m else raw


def format_disk(raw: str) -> str:
    parts = raw.split()
    if len(parts) >= 5:
        used_pct = parts[4].rstrip("%")
        free = parts[3]
        return f"{used_pct}% занято, {free} свободно"
    return raw


def format_mem(raw: str) -> str:
    parts = raw.split()
    if len(parts) >= 7:
        return f"{parts[2]} занято / {parts[6]} доступно"
    return raw


def collect_host_metrics(getter) -> tuple[str, str, str] | None:
    uptime_raw = getter(["uptime"])
    disk_raw = getter(["sh", "-c", "df -h / | tail -1"])
    mem_raw = getter(["sh", "-c", "free -h | awk 'NR==2'"])
    if not any((uptime_raw, disk_raw, mem_raw)):
        return None
    return (
        format_uptime(uptime_raw),
        format_disk(disk_raw),
        format_mem(mem_raw),
    )


def host_metrics_local() -> tuple[str, str, str] | str:
    def getter(cmd: list[str]) -> str:
        _, out = run_local(cmd)
        return out

    data = collect_host_metrics(getter)
    if data is None:
        return "нет данных"
    return data


def check_local(name: str, url: str) -> tuple[str, bool]:
    code, _ = run_local(["curl", "-sf", url, "-o", "/dev/null"])
    return name, code == 0


def health_checks_local() -> list[tuple[str, bool]]:
    return [
        check_local("Remnawave", "http://127.0.0.1:3001/health"),
        check_local("Uptime Kuma", "http://127.0.0.1:3002/dashboard"),
        check_local("AWG Panel", "http://127.0.0.1:5000/"),
        check_local("vpn2.sharpmaind.ru", "https://vpn2.sharpmaind.ru/"),
        check_local("awg.sharpmaind.ru", "https://awg.sharpmaind.ru/"),
    ]


def awg_dacha_handshake() -> tuple[str, bool]:
    code, out = run_local(
        [
            "docker",
            "exec",
            "amnezia-awg2",
            "awg",
            "show",
            "awg0",
            "dump",
        ]
    )
    if code != 0:
        return "AWG дача (10.8.1.8)", False
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) >= 4 and parts[3] == "10.8.1.8/32":
            hs = int(parts[4] or "0")
            age = "нет handshake" if hs == 0 else f"handshake {hs}"
            return f"AWG дача (10.8.1.8, {age})", hs > 0
    return "AWG дача (10.8.1.8)", False


def docker_lines_local() -> list[tuple[str, bool, str]]:
    code, out = run_local(
        ["docker", "ps", "--format", "{{.Names}}|{{.Status}}"]
    )
    if code != 0:
        return [("docker", False, out or "error")]
    lines: list[tuple[str, bool, str]] = []
    for row in out.splitlines():
        if "|" not in row:
            continue
        name, status = row.split("|", 1)
        lines.append((name.strip(), "Up" in status, status.strip()))
    return lines or [("docker", False, "нет контейнеров")]


def format_metrics_block(metrics: tuple[str, str, str] | str) -> str:
    if isinstance(metrics, str):
        return esc(metrics)
    uptime, disk, mem = metrics
    return (
        f"⏱ Uptime: {esc(uptime)}\n"
        f"📀 Диск: {esc(disk)}\n"
        f"🧠 RAM: {esc(mem)}"
    )


def format_checks_block(checks: list[tuple[str, bool]] | str) -> str:
    if isinstance(checks, str):
        return esc(checks)
    return "\n".join(f"{icon(ok)} {esc(name)}" for name, ok in checks)


def format_docker_block(lines: list[tuple[str, bool, str]] | str) -> str:
    if isinstance(lines, str):
        return esc(lines)
    return "\n".join(
        f"{icon(up)} <code>{esc(name)}</code> — {esc(status)}"
        for name, up, status in lines
    )


def build_status_text() -> str:
    checks = health_checks_local()
    checks.append(awg_dacha_handshake())
    torrent_line = "\n\n<b>P2P / torrent</b>\n⚠️ статус среза недоступен — /torrent"
    try:
        cut_on = get_torrent_cut_enabled()
        torrent_line = (
            "\n\n<b>P2P / torrent</b>\n"
            f"{'🟢 срез ВКЛ' if cut_on else '🔴 срез ВЫКЛ'} — /torrent"
        )
    except Exception as exc:
        torrent_line = (
            "\n\n<b>P2P / torrent</b>\n"
            f"⚠️ {esc(str(exc)[:120])} — /torrent"
        )
    return (
        "<b>📡 SharpVPN — FI сервер</b>\n\n"
        f"🇫🇮 <b>Финляндия</b> <code>{esc(FI_IP)}</code>\n"
        f"{format_metrics_block(host_metrics_local())}\n\n"
        f"<b>Сервисы</b>\n"
        f"{format_checks_block(checks)}"
        f"{torrent_line}\n\n"
        f"<b>Docker</b>\n"
        f"{format_docker_block(docker_lines_local())}"
    )


def reboot_local() -> None:
    subprocess.Popen(["/usr/sbin/reboot"], start_new_session=True)


def confirm_keyboard() -> InlineKeyboardMarkup:
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton(
                    "✅ Да, перезагрузить",
                    callback_data="reboot:fi:yes",
                ),
                InlineKeyboardButton("❌ Отмена", callback_data="reboot:cancel"),
            ]
        ]
    )


def remnawave_configured() -> bool:
    return bool(REMNAWAVE_API_TOKEN and REMNAWAVE_NODE_UUID)


def remnawave_request(
    method: str, path: str, body: dict | None = None, timeout: int = 60
) -> dict:
    if not remnawave_configured():
        raise RuntimeError("Remnawave API не настроен (нет token/node)")
    url = f"{REMNAWAVE_BASE_URL}{path}"
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {REMNAWAVE_API_TOKEN}",
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "vpn-bot/torrent-cut-toggle",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")[:300]
        raise RuntimeError(f"HTTP {exc.code}: {detail}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"сеть: {exc.reason}") from exc


def get_active_profile_uuid() -> str:
    if REMNAWAVE_PROFILE_UUID:
        return REMNAWAVE_PROFILE_UUID
    payload = remnawave_request("GET", "/api/nodes/")
    nodes = payload.get("response")
    if isinstance(nodes, dict):
        nodes = nodes.get("nodes") or []
    if not isinstance(nodes, list):
        raise RuntimeError("не удалось получить список нод")
    node = next((n for n in nodes if n.get("uuid") == REMNAWAVE_NODE_UUID), None)
    if not node:
        raise RuntimeError("нода не найдена")
    profile = (node.get("configProfile") or {}).get("activeConfigProfileUuid")
    if not profile:
        raise RuntimeError("у ноды нет active config profile")
    return profile


def _is_bt_block_rule(rule: dict) -> bool:
    protos = rule.get("protocol") or []
    return "bittorrent" in protos and rule.get("outboundTag") == "BLOCK"


def get_profile_config(profile_uuid: str) -> dict:
    payload = remnawave_request("GET", f"/api/config-profiles/{profile_uuid}")
    config = (payload.get("response") or {}).get("config")
    if isinstance(config, str):
        config = json.loads(config)
    if not isinstance(config, dict):
        raise RuntimeError("config профиля пустой")
    return config


def get_torrent_cut_enabled() -> bool:
    profile_uuid = get_active_profile_uuid()
    config = get_profile_config(profile_uuid)
    rules = ((config.get("routing") or {}).get("rules")) or []
    return any(_is_bt_block_rule(r) for r in rules if isinstance(r, dict))


def set_torrent_cut_enabled(enabled: bool) -> bool:
    """Toggle Xray routing rule bittorrent→BLOCK. Never enables IP-ban plugin."""
    profile_uuid = get_active_profile_uuid()
    config = get_profile_config(profile_uuid)
    routing = dict(config.get("routing") or {})
    rules = [r for r in (routing.get("rules") or []) if not _is_bt_block_rule(r)]
    if enabled:
        rules.append(dict(BT_BLOCK_RULE))
    routing["rules"] = rules
    config["routing"] = routing

    remnawave_request(
        "PATCH",
        "/api/config-profiles/",
        {"uuid": profile_uuid, "config": config},
    )
    remnawave_request(
        "POST",
        f"/api/nodes/{REMNAWAVE_NODE_UUID}/actions/restart",
        {"forceRestart": False},
    )
    # Keep Remnawave IP-ban plugin off if configured.
    try:
        ensure_ip_ban_plugin_off()
    except Exception as exc:
        log.warning("IP-ban plugin ensure-off failed: %s", exc)
    return get_torrent_cut_enabled()


def ensure_ip_ban_plugin_off() -> None:
    if not REMNAWAVE_PLUGIN_UUID:
        return
    payload = remnawave_request("GET", f"/api/node-plugins/{REMNAWAVE_PLUGIN_UUID}")
    config = (payload.get("response") or {}).get("pluginConfig")
    if not isinstance(config, dict):
        return
    tb = dict(config.get("torrentBlocker") or {})
    if not tb.get("enabled"):
        return
    ignore = dict(tb.get("ignoreLists") or {})
    ignore.setdefault("ip", [])
    ignore.setdefault("userId", [])
    tb["enabled"] = False
    tb["ignoreLists"] = ignore
    tb["blockDuration"] = int(tb.get("blockDuration") or REMNAWAVE_BLOCK_DURATION)
    config["torrentBlocker"] = tb
    remnawave_request(
        "PATCH",
        "/api/node-plugins/",
        {"uuid": REMNAWAVE_PLUGIN_UUID, "pluginConfig": config},
    )
    remnawave_request(
        "POST",
        "/api/node-plugins/actions/sync",
        {"uuid": REMNAWAVE_PLUGIN_UUID},
    )


def torrent_keyboard(cut_on: bool) -> InlineKeyboardMarkup:
    toggle_label = "🔴 Выключить срез" if cut_on else "🟢 Включить срез"
    toggle_data = "torrent:off" if cut_on else "torrent:on"
    return InlineKeyboardMarkup(
        [
            [
                InlineKeyboardButton(toggle_label, callback_data=toggle_data),
                InlineKeyboardButton("🔄 Обновить", callback_data="torrent:refresh"),
            ]
        ]
    )


def torrent_status_text(cut_on: bool, note: str = "") -> str:
    state = "🟢 <b>ВКЛ</b>" if cut_on else "🔴 <b>ВЫКЛ</b>"
    text = (
        "<b>✂️ Срез bittorrent</b>\n\n"
        f"Статус: {state}\n"
        "Без бана юзеров и без бана IP.\n"
        "Правило в профиле: <code>bittorrent → BLOCK</code>."
    )
    if note:
        text += f"\n\n{esc(note)}"
    return text


async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        await deny(update)
        return
    await update.message.reply_text(HELP_TEXT)


async def cmd_myid(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id if update.effective_chat else "?"
    user_id = update.effective_user.id if update.effective_user else "?"
    allowed = "да" if is_allowed(update) else "нет"
    await update.message.reply_text(
        f"chat_id: <code>{esc(str(chat_id))}</code>\n"
        f"user_id: <code>{esc(str(user_id))}</code>\n"
        f"доступ: {allowed}",
        parse_mode="HTML",
    )


async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        await deny(update)
        return
    await update.message.reply_text("⏳ Собираю статус…")
    await update.message.reply_text(
        build_status_text(),
        parse_mode="HTML",
        disable_web_page_preview=True,
    )


async def cmd_reboot(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        await deny(update)
        return
    await update.message.reply_text(
        "Перезагрузить FI 🇫🇮?\nПодтвердите кнопкой ниже.",
        reply_markup=confirm_keyboard(),
    )


async def cmd_torrent(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if not is_allowed(update):
        await deny(update)
        return
    if not remnawave_configured():
        await update.message.reply_text(
            "Remnawave API не настроен (REMNAWAVE_API_TOKEN / NODE)."
        )
        return
    try:
        cut_on = get_torrent_cut_enabled()
    except Exception as exc:
        await update.message.reply_text(
            f"Не удалось получить статус среза:\n<code>{esc(str(exc))}</code>",
            parse_mode="HTML",
        )
        return
    await update.message.reply_text(
        torrent_status_text(cut_on),
        parse_mode="HTML",
        reply_markup=torrent_keyboard(cut_on),
    )


async def on_reboot_callback(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    query = update.callback_query
    await query.answer()
    if not is_allowed(update):
        await query.edit_message_text("Доступ запрещён.")
        return
    data = query.data or ""
    if data == "reboot:cancel":
        await query.edit_message_text("Отменено.")
        return
    if data == "reboot:fi:yes":
        await query.edit_message_text("🔄 Перезагрузка FI…")
        reboot_local()
        return
    await query.edit_message_text("Неизвестная команда.")


async def on_torrent_callback(
    update: Update, context: ContextTypes.DEFAULT_TYPE
) -> None:
    query = update.callback_query
    if not is_allowed(update):
        await query.answer("Доступ запрещён", show_alert=True)
        return
    data = query.data or ""
    if data == "torrent:refresh":
        await query.answer("Обновляю…")
        try:
            cut_on = get_torrent_cut_enabled()
            await query.edit_message_text(
                torrent_status_text(cut_on),
                parse_mode="HTML",
                reply_markup=torrent_keyboard(cut_on),
            )
        except Exception as exc:
            await query.edit_message_text(
                f"Ошибка чтения статуса:\n<code>{esc(str(exc))}</code>",
                parse_mode="HTML",
            )
        return

    if data not in {"torrent:on", "torrent:off"}:
        await query.answer("Неизвестная команда", show_alert=True)
        return

    want_on = data == "torrent:on"
    await query.answer("Включаю срез…" if want_on else "Выключаю срез…")
    await query.edit_message_text(
        "⏳ Применяю срез "
        f"{'ВКЛ' if want_on else 'ВЫКЛ'} (обновление профиля + soft restart)…"
    )
    try:
        cut_on = set_torrent_cut_enabled(want_on)
        note = (
            "Готово."
            if cut_on == want_on
            else "Статус после применения отличается — проверьте панель."
        )
        await query.edit_message_text(
            torrent_status_text(cut_on, note=note),
            parse_mode="HTML",
            reply_markup=torrent_keyboard(cut_on),
        )
    except Exception as exc:
        await query.edit_message_text(
            f"Не удалось переключить срез:\n<code>{esc(str(exc))}</code>",
            parse_mode="HTML",
        )


def validate_config() -> None:
    if not BOT_TOKEN or BOT_TOKEN == "change_me":
        log.error("BOT_TOKEN не задан в .env")
        sys.exit(1)
    if not ALLOWED_CHAT_IDS:
        log.warning(
            "ALLOWED_CHAT_IDS пуст — бот запустится, но команды недоступны. "
            "Используйте /myid и добавьте chat_id в .env"
        )
    if not remnawave_configured():
        log.warning(
            "Remnawave API не полностью настроен — /torrent будет недоступен"
        )


async def post_init(application: Application) -> None:
    await application.bot.set_my_commands(
        [
            BotCommand("start", "Главное меню"),
            BotCommand("status", "Статус FI сервера"),
            BotCommand("torrent", "Срез bittorrent on/off"),
            BotCommand("reboot", "Перезагрузка FI"),
            BotCommand("myid", "Показать Telegram ID"),
            BotCommand("help", "Справка"),
        ]
    )
    await application.bot.set_my_description(
        "Мониторинг FI VPN, срез torrent-трафика и перезагрузка по запросу."
    )


def main() -> None:
    validate_config()
    app = (
        Application.builder()
        .token(BOT_TOKEN)
        .post_init(post_init)
        .build()
    )
    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("help", cmd_start))
    app.add_handler(CommandHandler("myid", cmd_myid))
    app.add_handler(CommandHandler("status", cmd_status))
    app.add_handler(CommandHandler("torrent", cmd_torrent))
    app.add_handler(CommandHandler("reboot", cmd_reboot))
    app.add_handler(CallbackQueryHandler(on_reboot_callback, pattern=r"^reboot:"))
    app.add_handler(CallbackQueryHandler(on_torrent_callback, pattern=r"^torrent:"))
    log.info("vpn-bot started, allowed chats: %s", ALLOWED_CHAT_IDS or "(none)")
    app.run_polling(drop_pending_updates=True)


if __name__ == "__main__":
    main()
