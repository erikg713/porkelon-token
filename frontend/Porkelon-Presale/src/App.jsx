import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import WalletConnectProvider from '@walletconnect/web3-provider';
import abi from './abi.json';
import './index.css';

const PRESALE_ADDRESS = '0xYOUR_DEPLOYED_PRESALE_ADDRESS_HERE'; // Update after deploy
const PORK_ADDRESS = '0x7f024bd81c22dafae5ecca46912acd94511210d8'; // If needed for extras
const USDT_ADDRESS = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
const USDT_ABI = ['function approve(address spender, uint256 amount) public returns (bool)'];
const CHAIN_ID = 137; // Polygon
const RATE = 100000; // 1 = 100k PORK
const CAP = 500000000; // For display
const PER_WALLET_CAP = 10000000;

function App() {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [account, setAccount] = useState(null);
  const [contract, setContract] = useState(null);
  const [status, setStatus] = useState({ active: false, sold: '0', cap: '0', start: 0, end: 0, userPurchased: '0' });
  const [maticAmount, setMaticAmount] = useState('');
  const [usdtAmount, setUsdtAmount] = useState('');
  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState('');
  const [countdown, setCountdown] = useState('');

  useEffect(() => {
    if (account && provider) {
      initContract();
    }
    const timer = setInterval(updateCountdown, 1000);
    return () => clearInterval(timer);
  }, [account, provider, status.start, status.end]);

  async function initContract() {
    const presale = new ethers.Contract(PRESALE_ADDRESS, abi, provider);
    setContract(presale);
    await updateStatus(presale);
  }

  async function updateStatus(contractInst) {
    const active = await contractInst.isActive();
    const sold = ethers.formatEther(await contractInst.totalSold());
    const cap = ethers.formatEther(await contractInst.CAP());
    const start = Number(await contractInst.startTime());
    const end = Number(await contractInst.endTime());
    const userPurchased = account ? ethers.formatEther(await contractInst.purchased(account)) : '0';
    setStatus({ active, sold: parseFloat(sold), cap: parseFloat(cap), start, end, userPurchased: parseFloat(userPurchased) });
  }

  function updateCountdown() {
    const now = Math.floor(Date.now() / 1000);
    let diff = status.start - now;
    let prefix = 'Starts in: ';
    if (now >= status.start) {
      diff = status.end - now;
      prefix = status.active ? 'Ends in: ' : 'Ended ';
    }
    if (diff <= 0) {
      setCountdown('Presale Over');
      return;
    }
    const days = Math.floor(diff / 86400);
    const hours = Math.floor((diff % 86400) / 3600);
    const minutes = Math.floor((diff % 3600) / 60);
    const seconds = diff % 60;
    setCountdown(`${prefix}${days}d ${hours}h ${minutes}m ${seconds}s`);
  }

  async function connectMetaMask() {
    if (window.ethereum) {
      const prov = new ethers.BrowserProvider(window.ethereum);
      await switchNetwork();
      await prov.send('eth_requestAccounts', []);
      const sign = await prov.getSigner();
      const acc = await sign.getAddress();
      setProvider(prov);
      setSigner(sign);
      setAccount(acc);
    } else {
      alert('Install MetaMask!');
    }
  }

  async function connectWalletConnect() {
    const wcProvider = new WalletConnectProvider({
      rpc: { 137: 'https://polygon-rpc.com' },
      chainId: CHAIN_ID,
    });
    await wcProvider.enable();
    const prov = new ethers.BrowserProvider(wcProvider);
    await switchNetwork(wcProvider);
    const sign = await prov.getSigner();
    const acc = await sign.getAddress();
    setProvider(prov);
    setSigner(sign);
    setAccount(acc);
  }

  async function switchNetwork(customProvider = window.ethereum) {
    try {
      await customProvider.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${CHAIN_ID.toString(16)}` }],
      });
    } catch (err) {
      if (err.code === 4902) {
        await customProvider.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: `0x${CHAIN_ID.toString(16)}`,
            chainName: 'Polygon',
            rpcUrls: ['https://polygon-rpc.com'],
            nativeCurrency: { name: 'MATIC', symbol: 'MATIC', decimals: 18 },
            blockExplorerUrls: ['https://polygonscan.com'],
          }],
        });
      }
    }
  }

  function disconnect() {
    setAccount(null);
    setProvider(null);
    setSigner(null);
    setContract(null);
  }

  // Buy functions remain the same...
  async function buyWithMatic() {
    if (!contract || !signer) return;
    setLoading(true);
    try {
      const amountWei = ethers.parseEther(maticAmount);
      const tx = await contract.connect(signer).buyWithMatic({ value: amountWei });
      await tx.wait();
      setTxHash(tx.hash);
      await updateStatus(contract);
    } catch (err) {
      alert(err.message || 'Transaction failed');
    }
    setLoading(false);
  }

  async function buyWithUsdt() {
    if (!contract || !signer) return;
    setLoading(true);
    try {
      const usdtContract = new ethers.Contract(USDT_ADDRESS, USDT_ABI, signer);
      const amountUsdt = ethers.parseUnits(usdtAmount, 6);
      await (await usdtContract.approve(PRESALE_ADDRESS, amountUsdt)).wait();
      const tx = await contract.connect(signer).buyWithUsdt(amountUsdt);
      await tx.wait();
      setTxHash(tx.hash);
      await updateStatus(contract);
    } catch (err) {
      alert(err.message || 'Transaction failed');
    }
    setLoading(false);
  }

  function getPorkEstimate(isMatic) {
    if (isMatic && maticAmount) return (parseFloat(maticAmount) * RATE).toLocaleString() + ' PORK';
    if (!isMatic && usdtAmount) return (parseFloat(usdtAmount) * RATE).toLocaleString() + ' PORK';
    return '0 PORK';
  }

  return (
    <div className="app">
      <header>
        <img src="/logo.png" alt="PORK Logo" className="logo" />
        <h1>PORK Token Presale</h1>
        <p>1 MATIC or 1 USDT = 100,000 PORK | Cap: {CAP.toLocaleString()} PORK | Per Wallet: {PER_WALLET_CAP.toLocaleString()} PORK</p>
        {!account ? (
          <div className="connect-buttons">
            <button onClick={connectMetaMask}>Connect MetaMask</button>
            <button onClick={connectWalletConnect}>Connect WalletConnect</button>
          </div>
        ) : (
          <div>
            <p>Connected: {account.slice(0, 6)}...{account.slice(-4)}</p>
            <button onClick={disconnect}>Disconnect</button>
          </div>
        )}
      </header>

      <section className="status">
        <h2>Presale Status: {status.active ? 'Active' : 'Inactive'}</h2>
        <p className="countdown">{countdown}</p>
        <div className="progress">
          <progress value={status.sold} max={status.cap}></progress>
          <p>{status.sold.toLocaleString()} / {status.cap.toLocaleString()} PORK Sold ({((status.sold / status.cap) * 100).toFixed(2)}%)</p>
        </div>
        {account && <p>Your Purchased: {(status.userPurchased * RATE).toLocaleString()} PORK</p>}
      </section>

      {status.active && account && (
        <section className="buy">
          <div className="buy-matic">
            <h3>Buy with MATIC (Min 0.1, Max 5)</h3>
            <input type="number" placeholder="MATIC amount" value={maticAmount} onChange={e => setMaticAmount(e.target.value)} />
            <p>Receive: {getPorkEstimate(true)}</p>
            <button onClick={buyWithMatic} disabled={loading}>Buy</button>
          </div>

          <div className="buy-usdt">
            <h3>Buy with USDT (Min ~0.1, Max ~5)</h3>
            <input type="number" placeholder="USDT amount" value={usdtAmount} onChange={e => setUsdtAmount(e.target.value)} />
            <p>Receive: {getPorkEstimate(false)}</p>
            <button onClick={buyWithUsdt} disabled={loading}>Approve & Buy</button>
          </div>
        </section>
      )}

      {txHash && <p>Tx Success: <a href={`https://polygonscan.com/tx/${txHash}`} target="_blank" rel="noopener">View on PolygonScan</a></p>}

      <footer>
        <p>Contract: <a href={`https://polygonscan.com/address/${PRESALE_ADDRESS}`} target="_blank" rel="noopener">{PRESALE_ADDRESS}</a></p>
      </footer>
    </div>
  );
}

export default App;
