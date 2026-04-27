"""
A股短线情绪快照
用于根据涨停/跌停/炸板/连板等指标判断市场情绪阶段。
"""
try:
    import akshare as ak
except ImportError:
    ak = None

import io
import contextlib
from datetime import datetime, timedelta


SENTIMENT_RULES = {
    "冰点": {
        "position": "轻仓或空仓",
        "note": "情绪低迷，优先控制回撤。",
    },
    "亢奋": {
        "position": "重仓主线龙头",
        "note": "情绪高涨，聚焦主线辨识度。",
    },
    "分歧": {
        "position": "半仓参与",
        "note": "只做高辨识度标的，避免追高。",
    },
    "修复": {
        "position": "轻仓到半仓",
        "note": "观察主线回流与承接强度。",
    },
}


def _quiet_call(func, *args, **kwargs):
    """静默调用，屏蔽akshare的print输出"""
    sink = io.StringIO()
    with contextlib.redirect_stdout(sink), contextlib.redirect_stderr(sink):
        return func(*args, **kwargs)


def _is_trading_day():
    """简单判断：工作日"""
    return datetime.now().weekday() < 5


def get_sentiment_data():
    """
    抓取真实情绪数据。
    每个字段独立 try-catch，任一失败 data_fetch_success = False。
    """
    if ak is None or not _is_trading_day():
        return None

    data_fetch_success = True

    try:
        zt_df = _quiet_call(ak.stock_zt_pool_em)
        limit_ups = len(zt_df)
    except Exception:
        limit_ups = 0
        data_fetch_success = False

    try:
        dt_df = _quiet_call(ak.stock_zt_pool_dtgc_em)
        limit_downs = len(dt_df)
    except Exception:
        limit_downs = 0
        data_fetch_success = False

    try:
        zbgc_df = _quiet_call(ak.stock_zt_pool_zbgc_em)
        broken_boards = len(zbgc_df)
    except Exception:
        broken_boards = 0
        data_fetch_success = False

    # 连板高度
    max_board = 0
    if limit_ups > 0 and len(zt_df) > 0:
        try:
            cols = zt_df.columns.tolist()
            board_col = None
            for c in ["连板数", "连板", "B板次数"]:
                if c in cols:
                    board_col = c
                    break
            if board_col:
                max_board = int(zt_df[board_col].max())
        except Exception:
            max_board = 0
            data_fetch_success = False

    return {
        "limit_ups": limit_ups,
        "limit_downs": limit_downs,
        "broken_boards": broken_boards,
        "max_board": max_board,
        "data_fetch_success": data_fetch_success,
    }


def classify_market_sentiment(limit_ups, limit_downs, broken_rate, max_board):
    if limit_ups < 20 and limit_downs > 10 and max_board < 3:
        stage = "冰点"
    elif limit_ups > 80 and broken_rate < 15 and max_board > 5:
        stage = "亢奋"
    elif broken_rate > 25 or (20 <= limit_ups <= 80 and max_board >= 3):
        stage = "分歧"
    else:
        stage = "修复"

    return {
        "stage": stage,
        "position": SENTIMENT_RULES[stage]["position"],
        "note": SENTIMENT_RULES[stage]["note"],
        "metrics": {
            "limit_ups": limit_ups,
            "limit_downs": limit_downs,
            "broken_rate": broken_rate,
            "max_board": max_board,
        },
    }


def build_sentiment_snapshot(limit_ups=None, limit_downs=None, broken_boards=None, max_board=None):
    """
    构建情绪快照。
    若数据获取全部失败（data_fetch_success=False），返回专用状态，不输出情绪结论。
    """
    data_fetch_success = True

    if all(v is None for v in [limit_ups, limit_downs, broken_boards, max_board]):
        data = get_sentiment_data()
        if data is None:
            return {
                "stage": "（非交易日）",
                "position": "——",
                "note": "周末/节假日数据暂停。",
                "metrics": {},
                "data_unavailable": True,
            }
        limit_ups = data["limit_ups"]
        limit_downs = data["limit_downs"]
        broken_boards = data["broken_boards"]
        max_board = data["max_board"]
        data_fetch_success = data.get("data_fetch_success", True)

    # 数据获取有任意一项失败，不输出情绪结论
    if not data_fetch_success:
        return {
            "stage": "（数据获取失败）",
            "position": "——",
            "note": "情绪数据暂无法获取，请稍后重试。",
            "metrics": {},
            "data_unavailable": True,
        }

    total_limit_events = limit_ups + broken_boards
    broken_rate = 0.0 if total_limit_events == 0 else broken_boards / total_limit_events * 100
    snapshot = classify_market_sentiment(
        limit_ups=limit_ups,
        limit_downs=limit_downs,
        broken_rate=broken_rate,
        max_board=max_board,
    )
    snapshot["metrics"]["broken_boards"] = broken_boards
    snapshot["data_unavailable"] = False
    return snapshot


def format_sentiment_snapshot(snapshot):
    if snapshot.get("data_unavailable"):
        return f"情绪阶段: {snapshot['stage']} | {snapshot['note']}"
    metrics = snapshot["metrics"]
    if not metrics:
        return f"情绪阶段: {snapshot['stage']} | {snapshot['note']}"
    return (
        f"情绪阶段: {snapshot['stage']} | "
        f"仓位建议: {snapshot['position']} | "
        f"涨停:{metrics['limit_ups']} 跌停:{metrics['limit_downs']} "
        f"炸板:{metrics.get('broken_boards',0)} 炸板率:{metrics['broken_rate']:.1f}% "
        f"连板高度:{metrics['max_board']} | {snapshot['note']}"
    )


if __name__ == "__main__":
    print("\n=== 🎯 A股短线情绪快照 ===")
    snapshot = build_sentiment_snapshot()
    print(format_sentiment_snapshot(snapshot))
