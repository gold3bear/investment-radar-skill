"""
龙虎榜数据 - 东方财富数据中心
akshare: stock_lhb_detail_em(start_date, end_date)
"""
import akshare as ak
import pandas as pd
import sys
from datetime import datetime, timedelta

def format_amount(val):
    """格式化金额（亿元）"""
    if abs(val) >= 1e8:
        return f"{val/1e8:.2f}亿"
    elif abs(val) >= 1e4:
        return f"{val/1e4:.2f}万"
    return f"{val:.0f}"

def get_lhb_list(days=3, top=15):
    """获取最近N日的龙虎榜数据"""
    end_date = datetime.now().strftime("%Y%m%d")
    start_date = (datetime.now() - timedelta(days=days)).strftime("%Y%m%d")

    df = ak.stock_lhb_detail_em(start_date=start_date, end_date=end_date)

    # 取最新上榜日的数据
    latest_date = df['上榜日'].max()
    df_latest = df[df['上榜日'] == latest_date].copy()

    # 去重：同一股票同一日只留一条（取净买额最大的）
    df_latest = df_latest.sort_values('龙虎榜净买额', key=abs, ascending=False).drop_duplicates(subset=['代码', '上榜日'])

    # 分离净买入和净卖出
    df_buy = df_latest[df_latest['龙虎榜净买额'] > 0].nlargest(top, '龙虎榜净买额')
    df_sell = df_latest[df_latest['龙虎榜净买额'] < 0].nsmallest(top, '龙虎榜净买额')

    return df_buy, df_sell, latest_date

def print_lhb():
    print(f"\n=== 🐉 龙虎榜（最近3日, 上榜日: {datetime.now().strftime('%Y-%m-%d')}）===\n")

    try:
        df_buy, df_sell, latest_date = get_lhb_list(days=3, top=10)
    except Exception as e:
        print(f"获取龙虎榜数据失败: {e}")
        return

    print(f"📅 数据日期: {latest_date}\n")

    # 净买入榜
    print("【机构净买入 Top10】")
    print(f"{'代码':<8} {'名称':<10} {'收盘价':>8} {'涨跌幅':>8} {'净买额':>10} {'换手率':>7} {'上榜原因'}")
    print("-" * 90)
    for _, row in df_buy.iterrows():
        code = row['代码']
        name = row['名称']
        close = row['收盘价']
        chg = row['涨跌幅']
        net = row['龙虎榜净买额']
        turnover = row['换手率']
        reason = row['上榜原因'][:20] if pd.notna(row['上榜原因']) else ''
        arrow = '🔴' if chg > 0 else '🟢'
        print(f"{arrow}{code:<6} {name:<10} {close:>8.2f} {chg:>+7.2f}% {format_amount(net):>10} {turnover:>6.1f}%  {reason}")

    print()
    print("【机构净卖出 Top10】")
    print(f"{'代码':<8} {'名称':<10} {'收盘价':>8} {'涨跌幅':>8} {'净卖额':>10} {'换手率':>7} {'上榜原因'}")
    print("-" * 90)
    for _, row in df_sell.iterrows():
        code = row['代码']
        name = row['名称']
        close = row['收盘价']
        chg = row['涨跌幅']
        net = row['龙虎榜净买额']  # 负数
        turnover = row['换手率']
        reason = row['上榜原因'][:20] if pd.notna(row['上榜原因']) else ''
        arrow = '🔴' if chg > 0 else '🟢'
        print(f"{arrow}{code:<6} {name:<10} {close:>8.2f} {chg:>+7.2f}% {format_amount(net):>10} {turnover:>6.1f}%  {reason}")

    print()

if __name__ == "__main__":
    print_lhb()
