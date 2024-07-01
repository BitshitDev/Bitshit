// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Bitshit Token Contract
 *
 * @dev This contract implements an ERC20 token with additional features:
 *      - Controlled transaction windows
 *      - Random fee mechanism
 *      - Jackpot mechanism
 *      - Minting and burning capabilities
 *      - Voting power delegation
 *
 * @dev Developed by BeAWhale
 */
contract Bitshit {
    // Token details
    string public constant name = "Bitshit";
    string public constant symbol = "BST";
    uint8 public constant decimals = 18;
    uint256 public constant initialSupply = 69000000000000000000000000000 + 42690690000000000000000000;
    uint256 public totalSupply = initialSupply;
    uint256 public burnedSupply = 0;

    // Special addresses
    address public constant burnAddress = 0x00000000000000000000000000000000007011E7;
    address public immutable contractAddress;

    // Wallet addresses
    address public immutable publicSaleWallet;
    address public immutable communityIncentivesWallet;
    address public immutable teamAndAdvisorsWallet;
    address public immutable partnershipsWallet;
    address public immutable reserveFundWallet;

    // Mappings for balances and allowances
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Constants for transaction windows
    uint256 public constant transactionWindowDuration = 1 hours;
    uint256 public constant transactionWindowStart1 = 0; // 12:00 AM
    uint256 public constant transactionWindowStart2 = 12 hours; // 12:00 PM

    // Jackpot settings
    uint256 public constant JACKPOT_CHANCE = 144923; // 0.0144923% or 1 in 6900 chance
    uint256 public constant JACKPOT_MULTIPLIER = 10;

    // Transaction count for tracking
    uint256 public transactionCount = 0;

    // Events for logging
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event JackpotWinner(address indexed winner, uint256 jackpotAmount);
    event RandomValueGenerated(uint256 randomValue);
    event InitialDistribution(address indexed wallet, uint256 amount);
    event TokensBurned(address indexed burner, uint256 amount);

    /**
     * @dev Constructor to initialize wallets and distribute initial tokens.
     * @param _publicSaleWallet Address for public sale tokens
     * @param _communityIncentivesWallet Address for community incentives tokens
     * @param _teamAndAdvisorsWallet Address for team and advisors tokens
     * @param _partnershipsWallet Address for partnerships tokens
     * @param _reserveFundWallet Address for reserve fund tokens
     */
    constructor(
        address _publicSaleWallet,
        address _communityIncentivesWallet,
        address _teamAndAdvisorsWallet,
        address _partnershipsWallet,
        address _reserveFundWallet
    ) {
        require(_publicSaleWallet != address(0), "Public sale wallet is zero address");
        require(_communityIncentivesWallet != address(0), "Community incentives wallet is zero address");
        require(_teamAndAdvisorsWallet != address(0), "Team and advisors wallet is zero address");
        require(_partnershipsWallet != address(0), "Partnerships wallet is zero address");
        require(_reserveFundWallet != address(0), "Reserve fund wallet is zero address");

        publicSaleWallet = _publicSaleWallet;
        communityIncentivesWallet = _communityIncentivesWallet;
        teamAndAdvisorsWallet = _teamAndAdvisorsWallet;
        partnershipsWallet = _partnershipsWallet;
        reserveFundWallet = _reserveFundWallet;
        contractAddress = address(this);

        // Initial token distribution
        _distributeInitialTokens();
    }

    // Modifier to allow transactions only during specific windows
    modifier onlyDuringTradingWindow() {
        require(_isWithinTradingWindow(), "Trading is only allowed during the trading windows");
        _;
    }

    // Modifier to check valid transaction amount
    modifier validTransactionAmount(uint256 amount) {
        bytes memory amountString = bytes(toString(amount));
        require(amountString.length >= 2 && amountString[0] == '6' && amountString[1] == '9', "Invalid transfer amount: Not starting with 69");
    
        // Convert the string back to a number and check if it's a multiple of 10
        uint256 remainder = amount % 10**(amountString.length - 2);
        require(remainder == 0, "Invalid transfer amount: Must be a multiple of 10");
        _;
    }

    /**
     * @dev Checks if the current time is within the trading window.
     * @return true if within trading window, false otherwise
     */
    function _isWithinTradingWindow() private view returns (bool) {
        uint256 dayTimestamp = block.timestamp % (1 days);
        bool isInFirstWindow = (dayTimestamp >= transactionWindowStart1 && dayTimestamp < transactionWindowStart1 + transactionWindowDuration);
        bool isInSecondWindow = (dayTimestamp >= transactionWindowStart2 && dayTimestamp < transactionWindowStart2 + transactionWindowDuration);
        return isInFirstWindow || isInSecondWindow;
    }

    /**
     * @dev Returns the time until the next trading window.
     * @return time in seconds until the next trading window
     */
    function timeUntilNextTradingWindow() public view returns (uint256) {
        uint256 dayTimestamp = block.timestamp % (1 days);

        if (dayTimestamp < transactionWindowStart1) {
            return transactionWindowStart1 - dayTimestamp;
        } else if (dayTimestamp >= transactionWindowStart1 && dayTimestamp < transactionWindowStart1 + transactionWindowDuration) {
            return 0;
        } else if (dayTimestamp < transactionWindowStart2) {
            return transactionWindowStart2 - dayTimestamp;
        } else if (dayTimestamp >= transactionWindowStart2 && dayTimestamp < transactionWindowStart2 + transactionWindowDuration) {
            return 0;
        } else {
            return 1 days - dayTimestamp + transactionWindowStart1;
        }
    }

    /**
     * @dev Distributes initial tokens to designated wallets.
     */
    function _distributeInitialTokens() private {
        uint256 publicSaleTokens = 21345345000000000000000000; // 21,345,345 tokens
        uint256 communityIncentivesTokens = 8538138000000000000000000; // 8,538,138 tokens
        uint256 teamAndAdvisorsTokens = 6403604000000000000000000; // 6,403,604 tokens
        uint256 partnershipsTokens = 4269069000000000000000000; // 4,269,069 tokens
        uint256 reserveFundTokens = 2134534500000000000000000; // 2,134,534.5 tokens

        balanceOf[burnAddress] = 69000000000000000000000000000; // instantly burning tokens
        balanceOf[publicSaleWallet] = publicSaleTokens;
        balanceOf[communityIncentivesWallet] = communityIncentivesTokens;
        balanceOf[teamAndAdvisorsWallet] = teamAndAdvisorsTokens;
        balanceOf[partnershipsWallet] = partnershipsTokens;
        balanceOf[reserveFundWallet] = reserveFundTokens;

        emit InitialDistribution(publicSaleWallet, publicSaleTokens);
        emit InitialDistribution(communityIncentivesWallet, communityIncentivesTokens);
        emit InitialDistribution(teamAndAdvisorsWallet, teamAndAdvisorsTokens);
        emit InitialDistribution(partnershipsWallet, partnershipsTokens);
        emit InitialDistribution(reserveFundWallet, reserveFundTokens);
    }

    /**
     * @dev Burns initial tokens from the total supply.
     * @param amount Amount of tokens to burn
     */
    function _burnInitialTokens(uint256 amount) private {
        require(balanceOf[publicSaleWallet] + balanceOf[communityIncentivesWallet] + balanceOf[teamAndAdvisorsWallet] + balanceOf[partnershipsWallet] + balanceOf[reserveFundWallet] >= amount, "Insufficient balance to burn");

        totalSupply -= amount;
        burnedSupply += amount;

        emit TokensBurned(contractAddress, amount);
    }

    /**
     * @dev Converts a uint256 to a string.
     * @param value The uint256 to convert
     * @return The string representation of the uint256
     */
    function toString(uint256 value) public pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Calculates a random value for the fee and jackpot.
     * @return Random value
     */
    function _calculateRandomValue() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, transactionCount))) % 1000000000;
    }

    /**
     * @dev Adjusts the fee and returns the net amount and fee amount.
     * @param randomValue Random value generated for the fee
     * @param amount Transaction amount
     * @return netAmount Net amount after fee adjustment
     * @return feeAmount Fee amount
     * @return feeIsPositive True if the fee is positive, false if negative
     */
    function _adjustFee(uint256 randomValue, uint256 amount) private view returns (uint256, uint256, bool) {
        int256 feePercentage = int256(randomValue % 8389) - 4169; // range: -41.69% to 42.0%
        int256 fee = (feePercentage * int256(amount)) / 10000;
        uint256 feeAmount = uint256(fee < 0 ? -fee : fee);
        uint256 netAmount = uint256(int256(amount) - fee);
        bool feeIsPositive = true;

        // Ensure fee is positive if the contract cannot pay a negative fee
        if (fee < 0) {
            if (feeAmount <= balanceOf[contractAddress]) {
                feeIsPositive = false;
                netAmount = uint256(int256(amount) - fee);
            } else {
                feeIsPositive = true;
                fee = -fee;
                feeAmount = uint256(fee);
                netAmount = amount - feeAmount;
            }
        }

        return (netAmount, feeAmount, feeIsPositive);
    }

    /**
     * @dev Handles the jackpot distribution.
     * @param to Address of the recipient
     * @param amount Amount of tokens transferred
     */
    function _handleJackpot(address to, uint256 amount) private {
        uint256 jackpotAmount = amount * JACKPOT_MULTIPLIER;
        uint256 availableJackpot = balanceOf[contractAddress] * 9 / 10;
        uint256 payoutAmount = availableJackpot > jackpotAmount ? jackpotAmount : availableJackpot;

        balanceOf[contractAddress] -= payoutAmount;
        balanceOf[to] += payoutAmount;

        emit JackpotWinner(to, payoutAmount);
    }

    /**
     * @notice Transfers tokens with fee adjustment and potential jackpot.
     * @param to Address to transfer tokens to
     * @param amount Amount of tokens to transfer
     * @return success True on successful transfer, reverts otherwise
     */
    function transfer(address to, uint256 amount) public onlyDuringTradingWindow validTransactionAmount(amount) returns (bool success) {
        uint256 randomValue = _calculateRandomValue();
        emit RandomValueGenerated(randomValue);

        if (randomValue < JACKPOT_CHANCE) {
            _handleJackpot(to, amount);
        } else {
            (uint256 netAmount, uint256 feeAmount, bool feeIsPositive) = _adjustFee(randomValue, amount);
            require(balanceOf[msg.sender] >= amount, "Insufficient balance");
            require(balanceOf[to] + netAmount >= balanceOf[to], "Overflow error");

            balanceOf[msg.sender] -= amount;
            balanceOf[to] += netAmount;

            if (feeAmount > 0) {
                if (feeIsPositive) {
                    balanceOf[contractAddress] += feeAmount;
                } else {
                    balanceOf[contractAddress] -= feeAmount;
                }
            }

            emit Transfer(msg.sender, to, netAmount);

            transactionCount++;
        }

        return true;
    }

    /**
     * @notice Approves an allowance for a spender.
     * @param spender Address of the spender
     * @param amount Amount of tokens to approve
     * @return success True on successful approval, reverts otherwise
     */
    function approve(address spender, uint256 amount) public returns (bool success) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /**
     * @notice Transfers tokens from an approved address with fee adjustment and potential jackpot.
     * @param from Address to transfer tokens from
     * @param to Address to transfer tokens to
     * @param amount Amount of tokens to transfer
     * @return success True on successful transfer, reverts otherwise
     */
    function transferFrom(address from, address to, uint256 amount) public onlyDuringTradingWindow validTransactionAmount(amount) returns (bool success) {
        uint256 randomValue = _calculateRandomValue();
        emit RandomValueGenerated(randomValue);

        if (randomValue < JACKPOT_CHANCE) {
            _handleJackpot(to, amount);
        } else {
            (uint256 netAmount, uint256 feeAmount, bool feeIsPositive) = _adjustFee(randomValue, amount);
            require(balanceOf[from] >= amount, "Insufficient balance");
            require(balanceOf[to] + netAmount >= balanceOf[to], "Overflow error");

            balanceOf[from] -= amount;
            balanceOf[to] += netAmount;

            if (feeAmount > 0) {
                if (feeIsPositive) {
                    balanceOf[contractAddress] += feeAmount;
                } else {
                    balanceOf[contractAddress] -= feeAmount;
                }
            }

            allowance[from][msg.sender] -= amount;

            emit Transfer(from, to, netAmount);

            transactionCount++;
        }

        return true;
    }

    /**
     * @notice Burns tokens, reducing the total supply.
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) public {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        burnedSupply += amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, burnAddress, amount);
    }
}
