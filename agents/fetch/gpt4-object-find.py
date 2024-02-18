from uagents import Agent, Bureau, Context, Model
import requests
from dotenv import load_dotenv; load_dotenv(); import os

agent = Agent(name="agent", seed="recovery phares woof woof roof roof")

# Here we demonstrate how your agent can request data and send an alert to your wallet.
#
# In this example we will use:
# - 'agent': this is your instance of the 'Agent' class that we will give an 'on_interval' task
# - 'ctx': this is the agent's 'Context', which gives you access to all the agent's important functions
# - 'requests': this is a module that allows you to make HTTP requests
#



def get_btc_price():
    response = requests.get(BTC_PRICE_URL)
    if response.status_code == 200:
        data = response.json()
        return data['bpi']['USD']['rate']
    return None

@agent.on_interval(period=10)
async def log_btc_price(ctx: Context):
    price = get_btc_price()

    stored_threshold = ctx.storage.get("threshold")

    # If the threshold has changed, reset the last update state to 0, otherwise retrieve from storage
    if stored_threshold and THRESHOLD_USD != stored_threshold:
        last_update_over_threshold = 0
    else:
        last_update_over_threshold = ctx.storage.get("last_update_over_threshold") or 0
    ctx.storage.set("threshold", THRESHOLD_USD)

    # Only produce an alert if the price has moved across the threshold in either direction
    alert = None
    if price:
        ctx.logger.info(f"The current Bitcoin price is: {price} USD")
        if float(price.replace(",", "")) > THRESHOLD_USD:
            if not last_update_over_threshold:
                alert = f"The BTC price is now over the specified threshold: {price} > {THRESHOLD_USD} USD"
            ctx.storage.set("last_update_over_threshold", 1)
        else:
            if last_update_over_threshold:
                alert = f"The BTC price is back under the specified threshold: {price} < {THRESHOLD_USD} USD"
            ctx.storage.set("last_update_over_threshold", 0)
    else:
        ctx.logger.info(f"I couldn't get the Bitcoin price")

    if alert:
        ctx.logger.info(alert)
        if MY_WALLET_ADDRESS != "fetch1___":
            await ctx.send_wallet_message(MY_WALLET_ADDRESS, alert)
        else:
            ctx.logger.info("To receive wallet alerts, set 'MY_WALLET_ADDRESS' to your wallet address.")

