import { useCallback, useEffect, useState, useRef } from 'react';
import { ethers } from 'ethers';
import {
  PRESALE_ADDRESS,
  USDT_ADDRESS,
  USDT_ABI,
  CHAIN_ID,
  RPC,
  RATE,
  USDT_DECIMALS,
} from '../constants';

/**
 * usePresale - Encapsulates connection, contract initialization and common presale actions.
 * Keeps App component focused on UI.
 */
export default function usePresale() {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [account, setAccount] = useState(null);
  const [contract, setContract] = useState(null);
  const [status, setStatus] = useState({
    active: false,
    sold: 0,
    cap: 0,
    start: 0,
    end: 0,
    userPurchased: 0,
  });
  const [loading, setLoading] = useState(false);
  const [txHash, setTxHash] = useState('');
  const mounted = useRef(true);

  useEffect(() => {
    mounted.current = true;
    return () => {
      mounted.current = false;
    };
  }, []);

  // Initializes contract instance with a read-only provider (or signer when available).
  const initContract = useCallback(
    async (ethersProvider) => {
      if (!ethersProvider) return;
      try {
        const json = await import('../abi.json');
        const presale = new ethers.Contract(PRESALE_ADDRESS, json.default || json, ethersProvider);
        if (mounted.current) setContract(presale);
        await refreshStatus(presale, account);
      } catch (err) {
        // Fail silently; UI will show not-connected state.
        // In dev you might console.error(err);
      }
    },
    [account],
  );

  // Fetches and updates presale status fields that the UI needs.
  const refreshStatus = useCallback(
    async (contractInstance = contract, targetAccount = account) => {
      if (!contractInstance) return;
      try {
        const [active, totalSold, cap, startTime, endTime] = await Promise.all([
          contractInstance.isActive(),
          contractInstance.totalSold(),
          contractInstance.CAP(),
          contractInstance.startTime(),
          contractInstance.endTime(),
        ]);
        let userPurchased = 0;
        if (targetAccount) {
          userPurchased = await contractInstance.purchased(targetAccount);
        }
        // convert to human numbers using ethers.formatEther (presale uses 18 decimals)
        const sold = parseFloat(ethers.formatEther(totalSold));
        const capNum = parseFloat(ethers.formatEther(cap));
        const userBought = parseFloat(ethers.formatEther(userPurchased || 0));
        if (mounted.current) {
          setStatus({
            active,
            sold,
            cap: capNum,
            start: Number(startTime),
            end: Number(endTime),
            userPurchased: userBought,
          });
        }
      } catch (err) {
        // ignore; contract might be uninitialized
      }
    },
    [contract, account],
  );

  // Connect using MetaMask
  const connectMetaMask = useCallback(async () => {
    if (!window.ethereum) throw new Error('MetaMask not detected');
    const eth = window.ethereum;
    const prov = new ethers.BrowserProvider(eth, 'any');
    await prov.send('eth_requestAccounts', []);
    const net = await prov.getNetwork();
    // attempt network switch if not on desired chain
    if (net.chainId !== CHAIN_ID && eth.request) {
      try {
        await eth.request({
          method: 'wallet_switchEthereumChain',
          params: [{ chainId: `0x${CHAIN_ID.toString(16)}` }],
        });
      } catch (switchErr) {
        // try to add chain if missing (EIP-3085)
        if (switchErr?.code === 4902) {
          await eth.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: `0x${CHAIN_ID.toString(16)}`,
              chainName: 'Polygon',
              rpcUrls: [RPC],
              nativeCurrency: { name: 'MATIC', symbol: 'MATIC', decimals: 18 },
              blockExplorerUrls: ['https://polygonscan.com'],
            }],
          });
        } else {
          // don't block; user can still proceed
        }
      }
    }
    const sign = await prov.getSigner();
    const acc = await sign.getAddress();
    if (mounted.current) {
      setProvider(prov);
      setSigner(sign);
      setAccount(acc);
    }
    await initContract(prov);
    await refreshStatus(undefined, acc);
    return { provider: prov, signer: sign, account: acc };
  }, [initContract, refreshStatus]);

  // Connect using WalletConnect provider
  const connectWalletConnect = useCallback(async () => {
    const WalletConnectProvider = (await import('@walletconnect/web3-provider')).default;
    const wcProvider = new WalletConnectProvider({ rpc: { [CHAIN_ID]: RPC }, chainId: CHAIN_ID });
    await wcProvider.enable();
    const prov = new ethers.BrowserProvider(wcProvider, 'any');
    const sign = await prov.getSigner();
    const acc = await sign.getAddress();
    if (mounted.current) {
      setProvider(prov);
      setSigner(sign);
      setAccount(acc);
    }
    await initContract(prov);
    await refreshStatus(undefined, acc);
    return { provider: prov, signer: sign, account: acc, raw: wcProvider };
  }, [initContract, refreshStatus]);

  const disconnect = useCallback(() => {
    setAccount(null);
    setSigner(null);
    setProvider(null);
    setContract(null);
    setTxHash('');
  }, []);

  // Buy with native MATIC
  const buyWithMatic = useCallback(
    async (maticAmount) => {
      if (!contract || !signer) throw new Error('Wallet not connected');
      setLoading(true);
      try {
        const amountWei = ethers.parseEther(String(maticAmount));
        const tx = await contract.connect(signer).buyWithMatic({ value: amountWei });
        const receipt = await tx.wait();
        if (mounted.current) {
          setTxHash(receipt.transactionHash || tx.hash);
        }
        await refreshStatus();
        return receipt;
      } finally {
        if (mounted.current) setLoading(false);
      }
    },
    [contract, signer, refreshStatus],
  );

  // Buy with USDT (checks allowance first to avoid unnecessary approvals)
  const buyWithUsdt = useCallback(
    async (usdtAmount) => {
      if (!contract || !signer || !account) throw new Error('Wallet not connected');
      setLoading(true);
      try {
        const usdt = new ethers.Contract(USDT_ADDRESS, USDT_ABI, signer);
        const amount = ethers.parseUnits(String(usdtAmount), USDT_DECIMALS);

        // check allowance to avoid duplicate approve
        const allowance = await usdt.allowance(account, PRESALE_ADDRESS);
        if (BigInt(allowance.toString()) < BigInt(amount.toString())) {
          const approveTx = await usdt.approve(PRESALE_ADDRESS, amount);
          await approveTx.wait();
        }
        const tx = await contract.connect(signer).buyWithUsdt(amount);
        const receipt = await tx.wait();
        if (mounted.current) {
          setTxHash(receipt.transactionHash || tx.hash);
        }
        await refreshStatus();
        return receipt;
      } finally {
        if (mounted.current) setLoading(false);
      }
    },
    [contract, signer, account, refreshStatus],
  );

  // Small helper: estimates PORK for a given amount (either matic or usdt)
  const estimatePork = useCallback((amount) => {
    const numeric = Number(amount) || 0;
    return Math.floor(numeric * RATE);
  }, []);

  return {
    provider,
    signer,
    account,
    contract,
    status,
    loading,
    txHash,
    connectMetaMask,
    connectWalletConnect,
    disconnect,
    initContract,
    refreshStatus,
    buyWithMatic,
    buyWithUsdt,
    estimatePork,
    setTxHash, // exported for clearing or manual updates
  };
    }
