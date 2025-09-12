# Porkelon (PORK) â€” 12-Week Roadmap

This roadmap maps the verification, liquidity, marketing, and utility tasks into a practical 12-week timeline.
Place this file at `docs/roadmap.md` in your GitHub repository.

---

## Summary
Focus: verification & trust â†’ liquidity & exposure â†’ community & marketing â†’ technical utility â†’ ongoing ops.

---

## Week-by-week Plan

### Weeks 1-2: Phase 1 â€” Verification & Trust
- Week 1
  - Prepare high-res logo (transparent PNG) and token metadata.
  - Publish one-page tokenomics PDF and hosted webpage.
  - Submit metadata to Moonshot and Solscan (include mint address).
  - Create `docs/tokenomics.md`.
- Week 2
  - Submit Moonshot verification request; follow up with their team.
  - Publish the "How to find the real PORKELON" guide on `docs/how_to_buy.md`.
  - Create a verified link set (website, twitter, github, discord).

### Weeks 3-4: Phase 2 â€” Liquidity & Market Exposure
- Week 3
  - Create liquidity pair (PORKELON / USDC or PORKELON / SOL) on a chosen DEX.
  - Seed initial liquidity (decide % of supply) and document amounts.
  - Generate a `scripts/add_liquidity.sh` or JS script.
- Week 4
  - Lock a portion of liquidity and publish lock details on `docs/liquidity.md`.
  - Submit token to tracking sites (Dexscreener, Solana trackers).
  - Create basic analytics dashboard links in `README.md`.

### Weeks 5-6: Phase 3 â€” Community & Marketing
- Week 5
  - Launch social channels and invite initial community (Discord, X, Telegram).
  - Start a content calendar (memes, facts, AMAs).
  - Run a small giveaway / airdrop to bootstrap holders.
- Week 6
  - Outreach to small Solana influencers; arrange cross-promo.
  - Publish tutorials: "How to add PORKELON to Phantom" and "How to trade".
  - Update `docs/faq.md` with common Qs (fees, supply, mint address).

### Weeks 7-8: Phase 4 â€” Technical Utility & Ecosystem
- Week 7
  - Decide utility features: staking, burns, or exclusive access.
  - Prototype a simple staking smart contract or staking UI.
  - Add `contracts/` and `frontend/staking/` placeholders.
- Week 8
  - Research Token-2022 TransferFee / TransferHook migration (if required).
  - If moving to Token-2022, draft migration plan & communication plan.

### Weeks 9-10: Phase 5 â€” Governance & Security
- Week 9
  - Evaluate multisig options and set up a multisig for critical keys.
  - Publish transparency plan (monthly reports template in `docs/reports/`).
- Week 10
  - If budget allows, run a lightweight security audit or community review.
  - Implement any urgent fixes or clarifications.

### Weeks 11-12: Phase 6 â€” Growth Operations
- Week 11
  - Scale marketing campaigns (paid + organic), measure KPI.
  - Consider token utility launches or partnerships.
- Week 12
  - Consolidate progress report, liquidity & burn totals, marketing spend.
  - Roadmap review and planning for next 3 months.

---

## Where to place files in your repo (recommended structure)

```
/ (root)
â”œâ”€ docs/
â”‚  â”œâ”€ roadmap.md          # <-- This file (place here)
â”‚  â”œâ”€ tokenomics.md
â”‚  â”œâ”€ faq.md
â”‚  â””â”€ how_to_buy.md
â”œâ”€ scripts/
â”‚  â”œâ”€ add_liquidity.sh
â”‚  â”œâ”€ lock_liquidity.sh
â”‚  â””â”€ deploy_anchor.sh
â”œâ”€ contracts/
â”‚  â””â”€ anchor/             # Anchor program sources (programs/)
â”œâ”€ frontend/
â”‚  â””â”€ staking/            # staking UI prototype
â”œâ”€ .github/
â”‚  â””â”€ workflows/
â”‚     â””â”€ ci.yml
â””â”€ README.md
```

---

## How to use the Python generator script
I included a generator script (`scripts/generate_roadmap.py`) that writes `docs/roadmap.md`. Run it locally or in CI:

```bash
python3 scripts/generate_roadmap.py
```

It will overwrite `docs/roadmap.md` with the current roadmap content.

---

## Notes
- Keep `docs/` docs under source control and update them as tasks complete.
- Use PRs to change roadmap or tokenomics so the community can review.
- For sensitive keys or scripts that require private keys (e.g., adding liquidity), never commit secrets â€” use environment variables or GitHub Actions secrets.

---
