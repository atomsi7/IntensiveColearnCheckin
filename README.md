# IntensiveColearnCheckin

IntensiveColearnCheckin Dapp is as the form of the [IntensiveColearn](https://intensivecolearn.ing/) Checkin, but on chain, mantained and interacted with the smart contract.

## Features

### Original Features

- User can checkin each day, with a note.
- User who do not checkin twice in a week will be blocked.

- User can review all user's history.

### Addition Features

- User can review peer's notes, and like it or 'Meh' it(think it's unimpressive).
- The checkin note which got 'Meh' of 67% will be viewed as not checkin.
- The checkin note liked by orgnizer will be viewed as checkin.

## Tech Stack

- Frontend: React, TailwindCSS, RainbowKit, Wagmi, Vite
- Smart Contract: Solidity
- Dev Kit: Foundry

## TODOs

- [ ] Optimize how the checkin record is stored in the smart contract.
  - [ ] Optimize how the autocheck works.
