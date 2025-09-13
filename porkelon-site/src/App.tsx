import React from "react";
import { Twitter, Send, MessageCircle } from "lucide-react";
import BuyPorkButton from "./BuyPork";

function App() {
  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-900 via-black to-gray-900 text-white">
      {/* Hero */}
      <section className="flex flex-col items-center justify-center text-center py-20 px-4">
        <a href="/" className="hover:opacity-90 transition">
          <img
            src="/porkelon-logo.png"
            alt="Porkelon Logo"
            className="w-32 h-32 mb-6 rounded-full shadow-lg"
          />
        </a>
        <h1 className="text-5xl font-extrabold mb-4">Porkelon ($PORK)</h1>
        <p className="text-xl max-w-2xl mb-6">
          The meme token blasting off on Solana 🚀🐖. Community-powered, fun-fueled,
          and built for growth.
        </p>

        {/* Jupiter Buy Widget */}
        <BuyPorkButton />

        <a
          href="https://solscan.io/token/38wY9xCwHK1ui7p7Y1kDAE7cwCSmTVJy7RSGsk2gmoon"
          target="_blank"
          rel="noopener noreferrer"
          className="mt-6 inline-block px-6 py-3 bg-pink-600 rounded-2xl font-bold text-lg hover:bg-pink-500 transition"
        >
          View on Solscan
        </a>
      </section>

      {/* Live Chart */}
      <section className="py-16 px-6 bg-gray-800 rounded-3xl max-w-5xl mx-auto mb-12 shadow-lg">
        <h2 className="text-3xl font-bold text-center mb-10">Live Price Chart</h2>
        <iframe
          src="https://dexscreener.com/solana/38wY9xCwHK1ui7p7Y1kDAE7cwCSmTVJy7RSGsk2gmoon"
          className="w-full h-[500px] rounded-xl border border-gray-700"
          allowFullScreen
        ></iframe>
      </section>

      {/* Tokenomics */}
      <section className="py-16 px-6 bg-gray-800 rounded-3xl max-w-5xl mx-auto mb-12 shadow-lg">
        <h2 className="text-3xl font-bold text-center mb-10">Tokenomics</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 text-lg">
          <div className="bg-gray-900 p-6 rounded-2xl shadow">
            <p><strong>Total Supply:</strong> 1,000,000,000 $PORK</p>
            <p><strong>Blockchain:</strong> Solana</p>
            <p><strong>Ticker:</strong> $PORK</p>
          </div>
          <div className="bg-gray-900 p-6 rounded-2xl shadow">
            <ul className="space-y-2">
              <li>🔥 50% Burned</li>
              <li>🌍 30% Community & Marketing</li>
              <li>💧 10% Liquidity Pool</li>
              <li>👨‍💻 10% Team (locked 12 months)</li>
            </ul>
          </div>
        </div>
      </section>

      {/* Roadmap */}
      <section className="py-16 px-6 max-w-5xl mx-auto mb-12">
        <h2 className="text-3xl font-bold text-center mb-10">Roadmap</h2>
        <div className="grid gap-6 md:grid-cols-3">
          <div className="bg-gray-800 p-6 rounded-2xl shadow">
            <h3 className="font-bold text-xl mb-2">Phase 1</h3>
            <p>Token launch, community building, Solscan verification.</p>
          </div>
          <div className="bg-gray-800 p-6 rounded-2xl shadow">
            <h3 className="font-bold text-xl mb-2">Phase 2</h3>
            <p>Listings on CoinGecko & CMC, meme contests, NFT teasers.</p>
          </div>
          <div className="bg-gray-800 p-6 rounded-2xl shadow">
            <h3 className="font-bold text-xl mb-2">Phase 3</h3>
            <p>Exchange listings, staking pools, global Porkelon meme army.</p>
          </div>
        </div>
      </section>

      {/* Community */}
      <section className="py-16 px-6 text-center">
        <h2 className="text-3xl font-bold mb-6">Join the Community</h2>
        <div className="flex justify-center gap-6">
          <a
            href="https://twitter.com/porkelon"
            target="_blank"
            rel="noopener noreferrer"
            className="p-4 bg-gray-800 rounded-full hover:bg-gray-700 transition"
          >
            <Twitter size={28} />
          </a>
          <a
            href="https://t.me/porkelon"
            target="_blank"
            rel="noopener noreferrer"
            className="p-4 bg-gray-800 rounded-full hover:bg-gray-700 transition"
          >
            <Send size={28} />
          </a>
          <a
            href="https://discord.gg/porkelon"
            target="_blank"
            rel="noopener noreferrer"
            className="p-4 bg-gray-800 rounded-full hover:bg-gray-700 transition"
          >
            <MessageCircle size={28} />
          </a>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-6 bg-gray-900 text-center text-sm border-t border-gray-800">
        <p>Contract: 38wY9xCwHK1ui7p7Y1kDAE7cwCSmTVJy7RSGsk2gmoon</p>
        <p className="mt-2">© {new Date().getFullYear()} Porkelon. All rights reserved.</p>
      </footer>
    </div>
  );
}

export default App;
