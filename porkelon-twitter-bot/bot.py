import tweepy
import json
import random
import os
from dotenv import load_dotenv

load_dotenv()

# Twitter API credentials
API_KEY = os.getenv("API_KEY")
API_SECRET = os.getenv("API_SECRET")
ACCESS_TOKEN = os.getenv("ACCESS_TOKEN")
ACCESS_SECRET = os.getenv("ACCESS_SECRET")

# Authenticate
auth = tweepy.OAuth1UserHandler(API_KEY, API_SECRET, ACCESS_TOKEN, ACCESS_SECRET)
api = tweepy.API(auth)

# Load tweets
with open("tweets.json", "r") as f:
    tweets = json.load(f)

# Load available media (logo + banner in assets/)
media_folder = "assets"
media_files = [os.path.join(media_folder, f) for f in os.listdir(media_folder) if f.endswith((".png", ".jpg", ".jpeg"))]

# Pick a random tweet
tweet = random.choice(tweets)

# Decide if this tweet gets an image (50% chance)
use_image = bool(media_files) and random.choice([True, False])

try:
    if use_image:
        media_file = random.choice(media_files)
        api.update_status_with_media(status=tweet, filename=media_file)
        print(f"✅ Tweet posted with image: {media_file}")
    else:
        api.update_status(status=tweet)
        print("✅ Tweet posted (text only).")
except Exception as e:
    print("❌ Error posting tweet:", e)
