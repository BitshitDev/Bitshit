// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Bitshit Token Contract
 *
 * @dev Implements an ERC20 token with additional features:
 *      - Controlled transaction windows with custom pattern
 *      - Random fee mechanism
 *      - Jackpot mechanism
 *      - Rejection of "13" transactions
 *      - Delayed trading activation
 *      - Emergency pause on additional features
 *
 * @dev Built by BeAWhale
 */
contract Bitshit {
    // Token details
    string public constant name = "Bitshit"; // Token name
    string public constant symbol = "BITSHIT"; // Token symbol
    uint8 public constant decimals = 18; // Number of decimals
    uint256 public constant initialSupply = 690420420690690000000000000000; // Initial supply of tokens (690,420,420,690,690 with 18 decimals)
    uint256 public totalSupply = initialSupply; // Total supply of tokens
    uint256 public circulatingSupply = 420420690690000000000000000; // Circulating supply of tokens (420,420,690,690 with 18 decimals)
    uint256 public burnedSupply = 0; // Tracks the burned supply

    // Special burn address for token burns
    address public constant burnAddress = 0x00000000000000000000000000000000007011E7;
    address public immutable contractAddress; // Address of the contract

    // Initial token distribution wallets
    address public immutable publicSaleWallet;
    address public immutable communityIncentivesWallet;
    address public immutable teamAndAdvisorsWallet;
    address public immutable proofOfMemesWallet;
    address public immutable reserveFundWallet;

    // Mappings for storing balances, allowances, and whitelisting addresses
    mapping(address => uint256) private _actualBalances; // Actual token balances
    mapping(address => mapping(address => uint256)) public allowance; // Allowance for transfers
    mapping(address => bool) public whitelist; // Whitelisted addresses for fee bypass
    mapping(address => bool) private _canTransferBeforeTradingIsEnabled; // Accounts allowed to transfer before trading is enabled

    // Constants for defining trading windows
    uint256 public constant tradingWindowDuration = 1 hours; // Duration of a trading window (1 hour)
    uint256 public constant delayBetweenWindows = 11 hours; // Gap between two trading windows
    uint256 public constant weekDuration = 7 days; // 1-week gap after the second trading window
    uint256 public firstTradingWindowStartTime; // Timestamp when the first trading window starts

    // Jackpot settings
    uint256 public constant JACKPOT_CHANCE = 144923; // 0.0144923% chance for jackpot
    uint256 public constant JACKPOT_MULTIPLIER = 10; // Multiplier for jackpot payout

    // Track number of transactions
    uint256 public transactionCount = 0;

    // Flags for controlling trading and features
    bool public bitshitActive = false; // Activates extra functionality
    bool public tradingActive = false; // Activates token transfers
    bool public emergencyPaused = false; // Flag for emergency pause
    address public admin; // Admin of the contract

    // Events to log various activities
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event JackpotWinner(address indexed winner, uint256 jackpotAmount);
    event RandomValueGenerated(uint256 randomValue);
    event InitialDistribution(address indexed wallet, uint256 amount);
    event TokensBurned(address indexed burner, uint256 amount);
    event BitshitActivated(uint256 activationTimestamp);
    event BitshitDeactivated();
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);
    event AddressWhitelisted(address indexed addr);

    /**
     * @dev Constructor to set up initial distribution wallets and the admin.
     *      It also distributes the initial token supply to predefined wallets.
     */
    constructor(
        address _publicSaleWallet,
        address _communityIncentivesWallet,
        address _teamAndAdvisorsWallet,
        address _proofOfMemesWallet,
        address _admin
    ) {
        require(_publicSaleWallet != address(0), "Public sale wallet is zero address");
        require(_communityIncentivesWallet != address(0), "Community incentives wallet is zero address");
        require(_teamAndAdvisorsWallet != address(0), "Team and advisors wallet is zero address");
        require(_proofOfMemesWallet != address(0), "Partnerships wallet is zero address");
        require(_admin != address(0), "Admin is zero address");

        publicSaleWallet = _publicSaleWallet;
        communityIncentivesWallet = _communityIncentivesWallet;
        teamAndAdvisorsWallet = _teamAndAdvisorsWallet;
        proofOfMemesWallet = _proofOfMemesWallet;
        contractAddress = address(this);
        admin = _admin;

        _distributeInitialTokens(); // Distribute initial tokens to wallets

        // Set whitelisted addresses for bypassing fees
        whitelist[0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD] = true;
        whitelist[0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6] = true;
        whitelist[0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24] = true;

        // Allow some addresses to transfer before trading is enabled
        _canTransferBeforeTradingIsEnabled[0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD] = true;
        _canTransferBeforeTradingIsEnabled[0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6] = true;
        _canTransferBeforeTradingIsEnabled[0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24] = true;
        _canTransferBeforeTradingIsEnabled[admin] = true;
    }

    // Modifier to restrict access to the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller is not the admin");
        _;
    }

    // Modifier to ensure trading is active before executing certain actions
    modifier tradingIsActive() {
        require(tradingActive, "Trading is not active");

        // If emergencyPaused is true, skip Bitshit functionalities
        if (!emergencyPaused) {
            // When not paused, check for Bitshit functionalities (windows, etc.)
            require(
                (bitshitActive && (_isWithinTradingWindow() || _canTransferBeforeTradingIsEnabled[msg.sender])),
                "Bitshit functionalities are paused or outside trading window"
            );
        }
        _;
    }

    /**
     * @dev Activates the trading and additional features by the admin.
     */
    function activateBitshit() public onlyAdmin {
        require(!tradingActive, "Trading is already active");

        bitshitActive = true;
        tradingActive = true;
        firstTradingWindowStartTime = block.timestamp; // First trading window starts now
        emit BitshitActivated(firstTradingWindowStartTime);
    }

    /**
     * @dev Pauses or resumes the bitshit functionality in case of emergencies.
     */
    function emergencyPause() public onlyAdmin {
        emergencyPaused = !emergencyPaused; // Toggle emergency pause
    
        if (emergencyPaused) {
            emit BitshitDeactivated(); // When paused, extra functionalities are disabled
        } else {
            emit BitshitActivated(firstTradingWindowStartTime); // When resumed, extra functionalities are enabled
        }
    }

    function addToWhitelist(address addr) public onlyAdmin {
        whitelist[addr] = true;
    }

    /**
     * @dev Checks if the current time is within a trading window.
     * @return True if a trading window is currently open, otherwise false.
     */
    function _isWithinTradingWindow() private view returns (bool) {
        uint256 currentTime = block.timestamp;
        uint256 timeSinceFirstWindow = currentTime - firstTradingWindowStartTime;
    
        // Each cycle is composed of 1 hour open, 11 hours closed, then 1 week - 13 hours
        uint256 cycleDuration = (tradingWindowDuration + delayBetweenWindows) + (weekDuration - (tradingWindowDuration + delayBetweenWindows));
        uint256 timeInCycle = timeSinceFirstWindow % cycleDuration;
    
        // Check if the current time is within the 1-hour first window or the 1-hour second window
        if (timeInCycle < tradingWindowDuration || 
            (timeInCycle >= (tradingWindowDuration + delayBetweenWindows) && timeInCycle < (tradingWindowDuration * 2 + delayBetweenWindows))) {
            return true;
        }
    
        return false; // Otherwise, the trading window is closed
    }

    /**
 * @dev Returns the time in seconds until the next trading window opens.
 * @return Time in seconds until the next trading window starts, or 0 if trading is already open.
 */
    function whenWindowOpens() public view returns (uint256) {
    if (!tradingActive) {
        return 0; // Trading is not active
    }

    uint256 currentTime = block.timestamp;
    uint256 timeSinceFirstWindow = currentTime - firstTradingWindowStartTime;

    // Each cycle is composed of 1 hour open, 11 hours closed, then 1 week - 13 hours
    uint256 cycleDuration = (tradingWindowDuration + delayBetweenWindows) + (weekDuration - (tradingWindowDuration + delayBetweenWindows));
    uint256 timeInCycle = timeSinceFirstWindow % cycleDuration;

    // If we are in the trading window, return 0
    if (timeInCycle < tradingWindowDuration || 
        (timeInCycle >= (tradingWindowDuration + delayBetweenWindows) && timeInCycle < (tradingWindowDuration * 2 + delayBetweenWindows))) {
        return 0; // Trading window is currently open
    } else if (timeInCycle < (tradingWindowDuration + delayBetweenWindows)) {
        // If in the delay between windows, return the time until the second window opens
        return (tradingWindowDuration + delayBetweenWindows) - timeInCycle;
    } else {
        // If in the 1-week delay, return the time until the first window of the next cycle opens
        return cycleDuration - timeInCycle;
    }
    }
    
    /**
 * @dev Returns the time in seconds until the current trading window closes.
 * @return Time in seconds until the current trading window closes, or 0 if no window is currently open.
 */
    function whenWindowCloses() public view returns (uint256) {
    if (!tradingActive) {
        return 0; // Trading is not active
    }

    uint256 currentTime = block.timestamp;
    uint256 timeSinceFirstWindow = currentTime - firstTradingWindowStartTime;

    // Each cycle is composed of 1 hour open, 11 hours closed, then 1 week - 13 hours
    uint256 cycleDuration = (tradingWindowDuration + delayBetweenWindows) + (weekDuration - (tradingWindowDuration + delayBetweenWindows));
    uint256 timeInCycle = timeSinceFirstWindow % cycleDuration;

    // If in the first or second window, calculate remaining time
    if (timeInCycle < tradingWindowDuration) {
        return tradingWindowDuration - timeInCycle; // Time until first window closes
    } else if (timeInCycle >= (tradingWindowDuration + delayBetweenWindows) && timeInCycle < (tradingWindowDuration * 2 + delayBetweenWindows)) {
        return (tradingWindowDuration * 2 + delayBetweenWindows) - timeInCycle; // Time until second window closes
    } else {
        return 0; // No window is currently open
    }
    }

    /**
     * @dev Function to check if a transfer amount starts with '13'.
     * @param amount The amount to be checked.
     * @return True if the amount starts with 13, otherwise false.
     */
    function _startsWith13(uint256 amount) private pure returns (bool) {
        uint256 firstTwoDigits = amount;
        while (firstTwoDigits >= 100) {
            firstTwoDigits /= 10;
        }
        return firstTwoDigits == 13;
    }

    /**
     * @dev Validates that a transaction amount does not start with '13'.
     * @param amount The transaction amount.
     */
    function _validateTransactionAmount(uint256 amount) private view {
        if (!emergencyPaused) {
            uint256 firstTwoDigits = amount;
            while (firstTwoDigits >= 100) {
                firstTwoDigits /= 10;
            }
            require(firstTwoDigits != 13, "Invalid transfer amount: Starts with 13");
        }
    }

    /**
     * @dev Calculates a random value to be used in fee or jackpot logic.
     * @return A random value based on the transaction count and timestamp.
     */
    function _calculateRandomValue() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, transactionCount))) % 1000000000;
    }

    /**
     * @dev Adjusts the transaction fee based on a random value.
     * @param randomValue The random value calculated.
     * @param amount The transaction amount.
     * @return The net transaction amount, the fee, and a boolean indicating if the fee is positive.
     */
    function _adjustFee(uint256 randomValue, uint256 amount) private view returns (uint256, uint256, bool) {
        int256 feePercentage = int256(randomValue % 8389) - 4169; // Fee range: -41.69% to 42.19%
        int256 fee = (feePercentage * int256(amount)) / 10000;
        uint256 feeAmount = uint256(fee < 0 ? -fee : fee);
        uint256 netAmount = uint256(int256(amount) - fee);
        bool feeIsPositive = true;

        if (fee < 0) {
            if (feeAmount <= _actualBalances[contractAddress]) {
                feeIsPositive = false; // Negative fee (rebate)
            } else {
                feeIsPositive = true; // Positive fee if not enough balance for a rebate
                fee = -fee;
                feeAmount = uint256(fee);
                netAmount = amount - feeAmount;
            }
        }

        return (netAmount, feeAmount, feeIsPositive);
    }

    /**
     * @dev Handles the jackpot mechanism where the recipient can win a jackpot.
     * @param to The recipient of the jackpot.
     * @param amount The amount used to calculate the jackpot.
     */
    function _handleJackpot(address to, uint256 amount) private {
        uint256 jackpotAmount = amount * JACKPOT_MULTIPLIER;
        uint256 availableJackpot = _actualBalances[contractAddress] * 9 / 10;
        uint256 payoutAmount = availableJackpot > jackpotAmount ? jackpotAmount : availableJackpot;

        _actualBalances[contractAddress] -= payoutAmount;
        _actualBalances[to] += payoutAmount;

        emit JackpotWinner(to, payoutAmount);
    }

    /**
     * @dev Returns the balance of a particular address.
     * @param account The address to query.
     * @return The balance of the queried address.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _actualBalances[account];
    }

    /**
     * @dev Transfers tokens from the caller to another address, with fees and jackpot logic if applicable.
     *      If emergencyPaused is active, extra features like fees, jackpot, and "13" check are skipped.
     * @param to The recipient of the tokens.
     * @param amount The amount to be transferred.
     * @return success - true if the transfer is successful.
     */
    function transfer(address to, uint256 amount) public tradingIsActive returns (bool success) {
    require(to != address(0), "Cannot transfer to zero address");
    require(amount > 0, "Amount must be greater than zero");

    uint256 senderBalance = _actualBalances[msg.sender];
    require(senderBalance >= amount, "Insufficient balance");

    // Whitelisted addresses bypass fees and jackpot mechanism
    if (whitelist[msg.sender] || whitelist[to]) {
        _actualBalances[msg.sender] = senderBalance - amount;
        _actualBalances[to] += amount;
        emit Transfer(msg.sender, to, amount);
    } else {
        // If emergency pause is not active, apply extra features
        if (!emergencyPaused) {
            _validateTransactionAmount(amount); // Check if the amount starts with '13'

            uint256 randomValue = _calculateRandomValue();
            emit RandomValueGenerated(randomValue);

            // Jackpot mechanism
            if (randomValue < JACKPOT_CHANCE) {
                _handleJackpot(to, amount);
            } else {
                // Fee adjustment mechanism
                (uint256 netAmount, uint256 feeAmount, bool feeIsPositive) = _adjustFee(randomValue, amount);

                // Update balances after fee adjustment
                _actualBalances[msg.sender] = senderBalance - amount;
                _actualBalances[to] += netAmount;

                if (feeAmount > 0) {
                    if (feeIsPositive) {
                        _actualBalances[contractAddress] += feeAmount; // Contract collects the fee
                    } else {
                        _actualBalances[contractAddress] -= feeAmount; // Contract gives rebate
                    }
                }

                emit Transfer(msg.sender, to, netAmount);
                transactionCount++;
            }
        } else {
            // If emergencyPaused is active, perform a simple transfer
            _actualBalances[msg.sender] = senderBalance - amount;
            _actualBalances[to] += amount;
            emit Transfer(msg.sender, to, amount);
        }
    }

    return true;
    }


    /**
     * @dev Approves a spender to transfer tokens from the caller's account.
     * @param spender The address allowed to spend the tokens.
     * @param amount The amount approved for spending.
     * @return success - True if the approval is successful.
     */
    function approve(address spender, uint256 amount) public returns (bool success) {
        require(spender != address(0), "Cannot approve zero address");
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
    * @dev Transfers tokens from one address to another, with fees and jackpot logic if applicable.
    *      If emergencyPaused is active, extra features like fees, jackpot, and "13" check are skipped.
    * @param from The address transferring the tokens.
    * @param to The recipient of the tokens.
    * @param amount The amount to be transferred.
    * @return success - true if the transfer is successful.
    */
    function transferFrom(address from, address to, uint256 amount) public returns (bool success) {
        require(to != address(0), "Cannot transfer to zero address");
        require(amount > 0, "Amount must be greater than zero");
    
        uint256 fromBalance = _actualBalances[from];
        require(fromBalance >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Allowance exceeded");
    
        // Whitelisted addresses bypass fees and jackpot mechanism
    if (whitelist[from] || whitelist[to]) {
            _actualBalances[from] = fromBalance - amount;
         _actualBalances[to] += amount;
         emit Transfer(from, to, amount);
     } else {
         // If emergency pause is not active, apply extra features
         if (!emergencyPaused) {
             _validateTransactionAmount(amount); // Check if the amount starts with '13'
    
              uint256 randomValue = _calculateRandomValue();
               emit RandomValueGenerated(randomValue);
    
              // Jackpot mechanism
               if (randomValue < JACKPOT_CHANCE) {
                   _handleJackpot(to, amount);
               } else {
                   // Fee adjustment mechanism
                   (uint256 netAmount, uint256 feeAmount, bool feeIsPositive) = _adjustFee(randomValue, amount);
    
                  // Update balances after fee adjustment
                   _actualBalances[from] = fromBalance - amount;
                   _actualBalances[to] += netAmount;
    
                   if (feeAmount > 0) {
                       if (feeIsPositive) {
                           _actualBalances[contractAddress] += feeAmount; // Contract collects the fee
                       } else {
                           _actualBalances[contractAddress] -= feeAmount; // Contract gives rebate
                       }
                   }
    
                   // Update allowance
                   allowance[from][msg.sender] -= amount;
                   emit Transfer(from, to, netAmount);
                   transactionCount++;
               }
           } else {
               // If emergencyPaused is active, perform a simple transfer
               _actualBalances[from] = fromBalance - amount;
               _actualBalances[to] += amount;
               emit Transfer(from, to, amount);
           }
       }
    
       return true;
    }


    /**
     * @dev Distributes initial tokens to predefined wallets.
     */
    function _distributeInitialTokens() private {
        uint256 publicSaleTokens = 140000000000000000000000000000; // 140,000,000,000 tokens (33.3%)
        uint256 proofOfMemesTokens = 140000000000000000000000000000; // 140,000,000,000 tokens (33.3%)
        uint256 communityIncentivesTokens = 84000000000000000000000000000; // 84,000,000,000 tokens (20%)
        uint256 teamAndAdvisorsTokens = 56420690690000000000000000000; // 56,420,690,690 tokens (13.4%)

        _actualBalances[burnAddress] = 690000000000000000000000000000; // Burned supply (690 trillion)
        _actualBalances[publicSaleWallet] += publicSaleTokens;
        _actualBalances[proofOfMemesWallet] += proofOfMemesTokens;
        _actualBalances[communityIncentivesWallet] += communityIncentivesTokens;
        _actualBalances[teamAndAdvisorsWallet] += teamAndAdvisorsTokens;

        // Emit events for initial distribution
        emit InitialDistribution(publicSaleWallet, publicSaleTokens);
        emit InitialDistribution(communityIncentivesWallet, communityIncentivesTokens);
        emit InitialDistribution(teamAndAdvisorsWallet, teamAndAdvisorsTokens);
        emit InitialDistribution(proofOfMemesWallet, proofOfMemesTokens);
    }
}
