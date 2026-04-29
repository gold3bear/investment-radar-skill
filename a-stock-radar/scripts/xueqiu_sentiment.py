"""
雪球舆情抓取脚本
通过 OpenClaw 浏览器工具抓取雪球个股讨论数据。

使用方法（需要 OpenClaw 环境）：
    from xueqiu_sentiment import fetch_xueqiu_sentiment
    result = fetch_xueqiu_sentiment("SZ000651")  # 格力电器
"""

import json
import subprocess
import time
import re
from datetime import datetime
from typing import Optional


def fetch_xueqiu_sentiment(code: str) -> dict:
    """
    通过 OpenClaw 浏览器抓取雪球个股舆情数据。

    Args:
        code: 股票代码，格式如 SZ000651, SZ300750

    Returns:
        dict，包含:
        - price: 最新价
        - chg_pct: 涨跌幅
        - pe: 市盈率
        - pb: 市净率
        - dividend: 股息率
        - posts: list[dict] 讨论帖
        - sentiment: 舆情方向
    """
    # 确定市场前缀
    if code.startswith("SZ") or code.startswith("SH"):
        symbol = code.upper()
    elif len(code) == 6:
        # 自动判断
        if code.startswith("6"):
            symbol = f"SH{code}"
        else:
            symbol = f"SZ{code}"
    else:
        symbol = code

    url = f"https://xueqiu.com/S/{symbol}"

    # 调用 OpenClaw 浏览器抓取
    cmd = [
        "openclaw", "browser", "fetch",
        "--url", url,
        "--format", "text",
        "--timeout", "15",
    ]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=20,
        )
        html = result.stdout
    except Exception:
        html = ""

    # 解析雪球页面内容
    return parse_xueqiu_html(html, symbol)


def parse_xueqiu_html(html: str, symbol: str) -> dict:
    """
    解析雪球 HTML，提取舆情数据。
    由于雪球内容通过 JS 动态渲染，最可靠的提取方式是
    使用 OpenClaw browser tool 获取渲染后的 DOM 快照。

    本函数提供基于文本正则的降级解析。
    """
    sentiment_data = {
        "symbol": symbol,
        "fetch_time": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "price": None,
        "chg_pct": None,
        "pe": None,
        "pb": None,
        "dividend": None,
        "market_cap": None,
        "posts": [],
        "sentiment": "unknown",
        "key_signals": [],
        "note": "建议使用 OpenClaw browser tool 手动抓取雪球页面",
    }

    if not html:
        return sentiment_data

    # 价格提取
    price_match = re.search(r"¥?(\d+\.\d+)", html)
    if price_match:
        sentiment_data["price"] = float(price_match.group(1))

    # 涨跌幅
    pct_match = re.search(r"([+-]?\d+\.\d+)%", html)
    if pct_match:
        sentiment_data["chg_pct"] = float(pct_match.group(1))

    # PE/PB
    pe_match = re.search(r"市盈.*?[:：]\s*([\d.]+)", html)
    if pe_match:
        sentiment_data["pe"] = float(pe_match.group(1))

    pb_match = re.search(r"市净.*?[:：]\s*([\d.]+)", html)
    if pb_match:
        sentiment_data["pb"] = float(pb_match.group(1))

    # 股息率
    div_match = re.search(r"股息率[^<\n]*?[:：]\s*([\d.]+)%", html)
    if div_match:
        sentiment_data["dividend"] = float(div_match.group(1))

    # 舆情方向判断
    positive_words = ["回购", "注销", "分红", "业绩增长", "超预期", "低估", "值得买", "增持", "看好"]
    negative_words = ["减持", "风险", "暴雷", "亏损", "负债", "骗局", "减持", "跑", "垃圾"]
    content_text = html

    pos_count = sum(1 for w in positive_words if w in content_text)
    neg_count = sum(1 for w in negative_words if w in content_text)

    if pos_count > neg_count * 1.5:
        sentiment_data["sentiment"] = "正面"
    elif neg_count > pos_count * 1.5:
        sentiment_data["sentiment"] = "负面"
    elif pos_count > 0 or neg_count > 0:
        sentiment_data["sentiment"] = "分歧"
    else:
        sentiment_data["sentiment"] = "中性"

    # 关键信号
    for kw in positive_words + negative_words:
        if kw in content_text:
            sentiment_data["key_signals"].append(kw)

    sentiment_data["key_signals"] = list(set(sentiment_data["key_signals"]))[:10]

    return sentiment_data


def print_sentiment_report(data: dict):
    """格式化输出雪球舆情报告。"""
    print(f"\n{'='*50}")
    print(f"🐢 雪球舆情 — {data['symbol']}  [{data['fetch_time']}]")
    print(f"{'='*50}")

    if data["price"]:
        print(f"📊 最新价格：¥{data['price']}  {'+' if data['chg_pct'] >= 0 else ''}{data['chg_pct']}%")
    if data["pe"]:
        print(f"📊 市盈率：{data['pe']}x  |  市净率：{data.get('pb', '-')}x  |  股息率：{data.get('dividend', '-')}%")

    print(f"\n🎯 舆情方向：{data['sentiment']}")
    if data["key_signals"]:
        print(f"📌 关键词：{' / '.join(data['key_signals'][:8])}")

    if data["posts"]:
        print(f"\n💬 最新讨论（{len(data['posts'])}条）：")
        for i, post in enumerate(data["posts"][:5], 1):
            time_str = post.get("time", "")
            author = post.get("author", "匿名")
            content = post.get("content", "")[:80]
            print(f"  {i}. [{time_str}] {author}: {content}...")

    print(f"\n⚠️ 注意：数据通过降级解析获取，建议使用浏览器快照验证。")
    print(f"{'='*50}\n")


if __name__ == "__main__":
    import sys
    code = sys.argv[1] if len(sys.argv) > 1 else "SZ000651"
    data = fetch_xueqiu_sentiment(code)
    print_sentiment_report(data)
