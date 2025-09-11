### 🐖 Porkelon Twitter Bot 🚀🚀🚀###

An automated Twitter bot that posts promotional tweets for Porkelon Token ($PORK), live on Solana Moonshot.

The bot:

Randomly selects tweets from a feed (tweets.json).

Attaches the Porkelon logo/banner images 50% of the time.

Uses Tweepy + Twitter API (X Developer Platform).

Can be scheduled to post multiple times per day.



---

📦 Project Structure

porkelon-twitter-bot/
│── bot.py              # Main bot script
│── tweets.json         # Tweet feed (pre-written content)
│── requirements.txt    # Python dependencies
│── .env                # API keys (never commit this!)
│── assets/             # Images (logo.png, banner.png, memes)
│    ├── logo.png
│    ├── banner.png


---

⚙️ Setup Instructions

1. Clone Repository

git clone https://github.com/YOUR_USERNAME/porkelon-twitter-bot.git
cd porkelon-twitter-bot

2. Install Dependencies

pip install -r requirements.txt

3. Add API Keys

Create a .env file:

API_KEY=your_api_key
API_SECRET=your_api_secret
ACCESS_TOKEN=your_access_token
ACCESS_SECRET=your_access_secret

Get these keys from your Twitter Developer Account.

4. Add Tweets

Edit tweets.json to customize your Porkelon feed. Example:

[
  "🚀 Introducing $PORK — Porkelon Token 🐖💫 Now live on Solana & discoverable on #Moonshot!\n\nSupply: 60B | 1% burn fee fuels marketing 🔥\n\nMoonshot Address: 38wY9xCwHK1ui7p7Y1kDAE7cwCSmTVJy7RSGsk2gmoon\n\n#Solana #Crypto #MemeCoin"
]

5. Add Images

Place your logo.png, banner.png, or memes into the assets/ folder.


---

🚀 Run the Bot

python bot.py

The bot will:

Select a random tweet.

50% chance: attach a random image from assets/.

Post directly to your Twitter account.



---

⏰ Automation (Optional)

To post automatically every few hours:

Linux (cron job):

crontab -e

Add:

0 */4 * * * /usr/bin/python3 /path/to/porkelon-twitter-bot/bot.py

Windows (Task Scheduler):

Create a new task.

Set trigger to run every X hours.

Action: python bot.py.



---

📢 Example Tweet

🚀 Introducing $PORK — Porkelon Token 🐖💫
Now live on Solana & discoverable on #Moonshot!

Supply: 60B | 1% burn fee fuels marketing 🔥
Moonshot Address: 38wY9xCwHK1ui7p7Y1kDAE7cwCSmTVJy7RSGsk2gmoon

#Solana #Crypto #MemeCoin


---

🐷 Porkelon Token Info

Ticker: $PORK

Supply: 60 Billion

Burn: 1% per transaction (deflationary)

Marketing wallet: fuels growth & community 🚀

Moonshot Contract:

38wY9xCwHK1ui7p7Y1kDAE7cwCSmTVJy7RSGsk2gmoon



---

💡 Contributing

Fork, improve, and make PRs if you’d like to extend the bot (scheduler, advanced media rotation, hashtags, etc.).


---


