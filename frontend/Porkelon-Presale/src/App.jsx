import React, { useEffect, useMemo, useState } from 'react';
import { ethers } from 'ethers';
import usePresale from './hooks/usePresale';
import {
  RATE,
  CAP_DISPLAY,
  PER_WALLET_CAP,
  EXPLORER_TX,
  EXPLORER_ADDRESS,
  MIN_MATIC,
  MAX_MATIC,
  USDT_DECIMALS,
} from './constants';
import './index.css';

/**
 * App - Minimal, production-minded presale front-end.
 * - Moves logic into a custom hook (usePresale)
 * - Validates inputs before calling contract
 * - Uses readable UI feedback instead of alerts
 * - Keeps code easy to maintain and test
 */

function shortAddress(a = '') {
  if (!a) return '';
  return `${a.slice(0, 6)}...${a.slice(-4)}`;
}

function useCountdown(start, end, active) {
  const [text, setText] = useState('Loading...');
  useEffect(() => {
    let mounted = true;
    function update() {
      const now = Math.floor(Date.now() / 1000);
      let diff = start - now;
      let prefix = 'Starts in:';
      if (now >= start) {
        diff = end - now;
        prefix = active ? 'Ends in:' : 'Ended:';
      }
      if (diff <= 0) {
        if (mounted) setText('Presale Over');
        return;
      }
      const days = Math.floor(diff / 86400);
      const hours = Math.floor((diff % 86400) / 3600);
      const minutes = Math.floor((diff % 3600) / 60);
      const seconds = diff % 60;
      if (mounted) setText(`${prefix} ${days}d ${hours}h ${minutes}m ${seconds}s`);
    }
    update();
    const timer = setInterval(update, 1000);
    return () => {
      mounted = false;
      clearInterval(timer);
    };
  }, [start, end, active]);
  return text;
}

export default function App() {
  const {
    account,
    status,
    loading,
    txHash,
    connectMetaMask,
    connectWalletConnect,
    disconnect,
    buyWithMatic,
    buyWithUsdt,
    estimatePork,
  } = usePresale();

  const [error, setError] = useState('');
  const [maticAmount, setMaticAmount] = useState('');
  const [usdtAmount, setUsdtAmount] = useState('');

  const countdown = useCountdown(status.start, status.end, status.active);

  useEffect(() => {
    if (!account) {
      setMaticAmount('');
      setUsdtAmount('');
    }
  }, [account]);

  const porkEstimateMatic = useMemo(() => `${estimatePork(maticAmount).toLocaleString()} PORK`, [maticAmount, estimatePork]);
  const porkEstimateUsdt = useMemo(() => `${estimatePork(usdtAmount).toLocaleString()} PORK`, [usdtAmount, estimatePork]);

  async function handleConnectMetaMask() {
    setError('');
    try {
      await connectMetaMask();
    } catch (err) {
      setError(err?.message || 'Connection failed');
    }
  }

  async function handleConnectWalletConnect() {
    setError('');
    try {
      await connectWalletConnect();
    } catch (err) {
      setError(err?.message || 'Connection failed');
    }
  }

  async function handleBuyWithMatic() {
    setError('');
    try {
      const amt = Number(maticAmount);
      if (!amt || isNaN(amt)) throw new Error('Enter a valid MATIC amount');
      if (amt < MIN_MATIC) throw new Error(`Minimum is ${MIN_MATIC} MATIC`);
      if (amt > MAX_MATIC) throw new Error(`Maximum is ${MAX_MATIC} MATIC`);
      await buyWithMatic(amt);
    } catch (err) {
      setError(err?.message || 'Buy failed');
    }
  }

  async function handleBuyWithUsdt() {
    setError('');
    try {
      const amt = Number(usdtAmount);
      if (!amt || isNaN(amt)) throw new Error('Enter a valid USDT amount');
      // Note: USDT may have different rounding; keep front-end limits simple
      if (amt < MIN_MATIC) throw new Error(`Minimum is approximately ${MIN_MATIC} USDT`);
      if (amt > MAX_MATIC) throw new Error(`Maximum is approximately ${MAX_MATIC} USDT`);
      await buyWithUsdt(amt);
    } catch (err) {
      setError(err?.message || 'Buy failed');
    }
  }

  return (
    <div className="app">
      <header className="header">
        <div className="brand">
          <img src="/logo.png" alt="PORK Logo" className="logo" />
          <div>
            <h1>PORK Token Presale</h1>
            <div className="sub">
              <span>1 MATIC / 1 USDT = {RATE.toLocaleString()} PORK</span>
              <span>Cap: {CAP_DISPLAY.toLocaleString()} PORK</span>
              <span>Per wallet: {PER_WALLET_CAP.toLocaleString()} PORK</span>
            </div>
          </div>
        </div>

        <div className="connect">
          {!account ? (
            <>
              <button className="btn" onClick={handleConnectMetaMask}>Connect MetaMask</button>
              <button className="btn outline" onClick={handleConnectWalletConnect}>WalletConnect</button>
            </>
          ) : (
            <>
              <div className="connected">Connected: {shortAddress(account)}</div>
              <button className="btn small" onClick={disconnect}>Disconnect</button>
            </>
          )}
        </div>
      </header>

      <main className="container">
        <section className="status">
          <h2>Presale Status: {status.active ? 'Active' : 'Inactive'}</h2>
          <p className="countdown">{countdown}</p>

          <div className="progress-block">
            <progress value={status.sold} max={status.cap}></progress>
            <div className="progress-meta">
              <div>{status.sold.toLocaleString()} / {status.cap.toLocaleString()} PORK Sold</div>
              <div>{(status.cap ? ((status.sold / status.cap) * 100).toFixed(2) : '0')}%</div>
            </div>
          </div>

          {account && <div className="user-purchased">You Purchased: {(status.userPurchased * RATE).toLocaleString()} PORK</div>}
        </section>

        {status.active && account && (
          <section className="buy">
            <div className="card">
              <h3>Buy with MATIC</h3>
              <input
                type="number"
                min="0"
                step="0.0001"
                placeholder={`MATIC (min ${MIN_MATIC}, max ${MAX_MATIC})`}
                value={maticAmount}
                onChange={(e) => setMaticAmount(e.target.value)}
              />
              <div className="muted">Receive: {porkEstimateMatic}</div>
              <button className="btn" disabled={loading} onClick={handleBuyWithMatic}>
                {loading ? 'Processing...' : 'Buy with MATIC'}
              </button>
            </div>

            <div className="card">
              <h3>Buy with USDT</h3>
              <input
                type="number"
                min="0"
                step={1 / (10 ** USDT_DECIMALS)}
                placeholder="USDT amount"
                value={usdtAmount}
                onChange={(e) => setUsdtAmount(e.target.value)}
              />
              <div className="muted">Receive: {porkEstimateUsdt}</div>
              <button className="btn" disabled={loading} onClick={handleBuyWithUsdt}>
                {loading ? 'Processing...' : 'Approve & Buy'}
              </button>
            </div>
          </section>
        )}

        {error && <div className="notice error">{error}</div>}
        {txHash && <div className="notice success">Transaction: <a href={EXPLORER_TX(txHash)} target="_blank" rel="noreferrer">View on PolygonScan</a></div>}

        <footer className="footer">
          Contract: <a href={EXPLORER_ADDRESS(process.env.REACT_APP_PRESALE_ADDRESS || '')} target="_blank" rel="noreferrer">{process.env.REACT_APP_PRESALE_ADDRESS || 'Set PRESALE_ADDRESS'}</a>
        </footer>
      </main>
    </div>
  );
}
