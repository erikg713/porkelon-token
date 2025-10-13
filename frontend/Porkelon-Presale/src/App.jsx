import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import abi from './abi.json';
import './index.css';

const PRESALE_ADDRESS = '0xYOUR_DEPLOYED_PRESALE_ADDRESS_HERE'; // Replace after deploy
const USDT_ADDRESS = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';
const USDT_ABI = ['function approve(address spender, uint256 amount) public returns (bool)'];
const CHAIN_ID = 137; // Polygon
const RATE = 100000; // 1 MATIC/USDT = 100k PORK

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

  useEffect(() => {
    if (account && provider) {
      initContract();
    }
  }, [account, provider]);

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
    setStatus({ active, sold, cap, start, end, userPurchased });
  }

  async function connectWallet() {
    if (window.ethereum) {
      const prov = new ethers.BrowserProvider(window.ethereum);
      await prov.send('eth_requestAccounts', []);
      const sign = await prov.getSigner();
      const acc = await sign.getAddress();
      const network = await prov.getNetwork();
      if (Number(network.chainId) !== CHAIN_ID) {
        alert('Switch to Polygon Network!');
        return;
      }
      setProvider(prov);
      setSigner(sign);
      setAccount(acc);
    } else {
      alert('Install MetaMask!');
    }
  }

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
      alert(err.message);
    }
    setLoading(false);
  }

  async function buyWithUsdt() {
    if (!contract || !signer) return;
    setLoading(true);
    try {
      const usdtContract = new ethers.Contract(USDT_ADDRESS, USDT_ABI, signer);
      const amountUsdt = ethers.parseUnits(usdtAmount, 6); // USDT 6 decimals
      await (await usdtContract.approve(PRESALE_ADDRESS, amountUsdt)).wait();
      const tx = await contract.connect(signer).buyWithUsdt(amountUsdt);
      await tx.wait();
      setTxHash(tx.hash);
      await updateStatus(contract);
    } catch (err) {
      alert(err.message);
    }
    setLoading(false);
  }

  function getTimeLeft() {
    const now = Math.floor(Date.now() / 1000);
    if (now < status.start) return 'Starts in ' + Math.floor((status.start - now) / 86400) + ' days';
    if (now > status.end) return 'Ended';
    return 'Ends in ' + Math.floor((status.end - now) / 86400) + ' days';
  }

  function getPorkEstimate(isMatic) {
    if (isMatic && maticAmount) return (parseFloat(maticAmount) * RATE).toFixed(0) + ' PORK';
    if (!isMatic && usdtAmount) return (parseFloat(usdtAmount) * RATE).toFixed(0) + ' PORK';
    return '0 PORK';
  }

  return (
    <div className="app">
      <header>
        <img src="/logo.png" alt="PORK Logo" className="logo" />
        <h1>PORK Token Presale</h1>
        <p>1 MATIC or 1 USDT = 100,000 PORK | Cap: 500M PORK | Per Wallet: 10M PORK</p>
        {!account ? (
          <button onClick={connectWallet}>Connect Wallet</button>
        ) : (
          <p>Connected: {account.slice(0, 6)}...{account.slice(-4)}</p>
        )}
      </header>

      <section className="status">
        <h2>Presale Status: {status.active ? 'Active' : 'Inactive'} ({getTimeLeft()})</h2>
        <div className="progress">
          <progress value={status.sold} max={status.cap}></progress>
          <p>{status.sold} / {status.cap} PORK Sold</p>
        </div>
        {account && <p>Your Purchased: { (parseFloat(status.userPurchased) * RATE / 100000).toFixed(2) } PORK (wait, adjust for decimals)</p>} {/* Adjust display if needed */}
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

      {txHash && <p>Tx: <a href={`https://polygonscan.com/tx/${txHash}`} target="_blank">View on PolygonScan</a></p>}

      <footer>
        <p>Contract: <a href={`https://polygonscan.com/address/${PRESALE_ADDRESS}`} target="_blank">{PRESALE_ADDRESS}</a></p>
        <p>Dev Wallet: YOUR_DEV_WALLET_HERE</p>
        {/* Add socials, whitepaper links */}
      </footer>
    </div>
  );
}

export default App;
