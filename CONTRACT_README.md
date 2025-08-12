# IntensiveColearnCheckin Smart Contract

This smart contract implements the IntensiveColearn checkin system on-chain, allowing users to check in daily with notes and participate in a peer review system.

## Features

### Core Functionality

- **Daily Checkins**: Users can check in once per day with a note
- **Peer Review System**: Users can like or "meh" other users' checkins
- **Organizer Controls**: Organizer can like checkins to mark them as valid
- **Blocking System**: Users who miss 2 checkins in a week can be blocked

### Key Rules

- Users can only check in once per day
- Checkins with 67% or more "meh" votes are considered invalid
- Organizer likes override the peer review system
- Blocked users cannot check in until unblocked

## Contract Functions

### User Functions

#### `checkin(string memory note)`

- Creates a new checkin for the current day
- Requires a non-empty note
- Can only be called once per day per user
- Emits `CheckinCreated` event

#### `likeCheckin(uint256 checkinId)`

- Likes a checkin (increases like count)
- Only non-organizers can like checkins
- Cannot like invalid checkins
- Emits `CheckinLiked` event

#### `mehCheckin(uint256 checkinId)`

- "Mehs" a checkin (increases meh count)
- Only non-organizers can meh checkins
- Cannot meh invalid checkins
- If meh percentage reaches 67%, checkin becomes invalid
- Emits `CheckinMehed` event

### Organizer Functions

#### `organizerLikeCheckin(uint256 checkinId)`

- Organizer can like a checkin to mark it as valid
- Only the contract owner can call this function
- Emits `CheckinLiked` event

#### `checkAndBlockUser(address user)`

- Checks if a user should be blocked for missing checkins
- Only the contract owner can call this function
- Blocks users who missed 2 checkins in a week
- Emits `UserBlocked` event

#### `unblockUser(address user)`

- Unblocks a previously blocked user
- Only the contract owner can call this function
- Emits `UserUnblocked` event

### View Functions

#### `getCheckin(uint256 checkinId)`

- Returns the details of a specific checkin
- Includes user, note, timestamp, likes, mehs, and validity status

#### `getUserStatus(address user)`

- Returns the status of a specific user
- Includes total checkins, consecutive missed days, and blocked status

#### `getUserCheckins(address user)`

- Returns an array of checkin IDs for a specific user

#### `getAllCheckins()`

- Returns an array of all checkin IDs in the system

#### `getTotalCheckins()`

- Returns the total number of checkins in the system

## Events

- `CheckinCreated(uint256 indexed checkinId, address indexed user, string note, uint256 timestamp)`
- `CheckinLiked(uint256 indexed checkinId, address indexed liker)`
- `CheckinMehed(uint256 indexed checkinId, address indexed meher)`
- `UserBlocked(address indexed user, uint256 week)`
- `UserUnblocked(address indexed user)`

## Constants

- `DAYS_IN_WEEK`: 7
- `MEH_THRESHOLD_PERCENTAGE`: 67 (67%)
- `SECONDS_IN_DAY`: 86400

## Deployment

To deploy the contract:

1. Set your private key as an environment variable:

   ```bash
   export PRIVATE_KEY=your_private_key_here
   ```

2. Run the deploy script:
   ```bash
   forge script script/Deploy.s.sol --rpc-url <your_rpc_url> --broadcast
   ```

## Testing

Run the test suite:

```bash
forge test
```

Run specific tests:

```bash
forge test --match-test testCheckin
forge test --match-test testMehThreshold
```

## Security Considerations

- The contract uses OpenZeppelin's `Ownable` for access control
- All user inputs are validated
- The blocking mechanism prevents abuse
- The peer review system has built-in safeguards against manipulation

## Gas Optimization

- Uses efficient storage patterns
- Minimizes storage reads and writes
- Optimized for the most common operations (checkin, like, meh)
