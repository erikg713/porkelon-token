const fs = require('fs');
const keccak256 = require('keccak256');
const { MerkleTree } = require('merkletreejs');

const holders = JSON.parse(fs.readFileSync('holders.json'));
const leaves = holders.map(x => keccak256(x.wallet + x.balance));
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });

fs.writeFileSync('merkleRoot.txt', tree.getHexRoot());

const proofs = holders.map(x => ({
    wallet: x.wallet,
    balance: x.balance,
    proof: tree.getHexProof(keccak256(x.wallet + x.balance))
}));
fs.writeFileSync('proofs.json', JSON.stringify(proofs, null, 2));

console.log('Merkle root and proofs generated.');
