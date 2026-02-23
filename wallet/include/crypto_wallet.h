/**
 * Liberty Reach Crypto Wallet
 * Multi-blockchain cryptocurrency wallet
 * Supports: Bitcoin, Ethereum, BSC, Polygon, Solana, TON, etc.
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <memory>
#include <functional>

namespace td {
namespace liberty_reach {
namespace wallet {

/**
 * Supported blockchains
 */
enum class Blockchain {
    BITCOIN,        // BTC
    ETHEREUM,       // ETH, ERC20
    BINANCE_SMART_CHAIN,  // BNB, BEP20
    POLYGON,        // MATIC
    SOLANA,         // SOL
    TON,            // Toncoin
    TRON,           // TRX
    AVALANCHE,      // AVAX
    CARDANO,        // ADA
    DOGECOIN,       // DOGE
    LITECOIN,       // LTC
    BITCOIN_CASH,   // BCH
    POLKADOT,       // DOT
    CHAINLINK,      // LINK
    UNISWAP,        // UNI
    LIBERTY_COIN    // Native Liberty Reach token
};

/**
 * Token standard
 */
enum class TokenStandard {
    NATIVE,     // Native coin (BTC, ETH, etc.)
    ERC20,      // Ethereum tokens
    BEP20,      // BSC tokens
    SPL,        // Solana tokens
    TRC20,      // Tron tokens
    TON_JETTON  // TON tokens
};

/**
 * Address structure
 */
struct WalletAddress {
    std::string address;
    Blockchain blockchain;
    TokenStandard standard;
    std::string label;
    bool is_default = false;
};

/**
 * Transaction structure
 */
struct Transaction {
    std::string id;
    std::string from;
    std::string to;
    double amount;
    std::string symbol;
    Blockchain blockchain;
    int64_t timestamp;
    int confirmations = 0;
    std::string status;  // "pending", "confirmed", "failed"
    std::string hash;
    double fee = 0.0;
    std::string memo;
};

/**
 * Balance structure
 */
struct Balance {
    double amount;
    double usd_value;
    std::string symbol;
    Blockchain blockchain;
};

/**
 * NFT structure
 */
struct NFT {
    std::string id;
    std::string name;
    std::string description;
    std::string image_url;
    std::string collection;
    Blockchain blockchain;
    std::string token_id;
    std::string contract_address;
};

/**
 * Wallet callbacks
 */
struct WalletCallbacks {
    std::function<void(const Transaction& tx)> on_transaction_received;
    std::function<void(const Transaction& tx)> on_transaction_sent;
    std::function<void(const std::string& error)> on_error;
    std::function<void(const std::string& status)> on_status_update;
};

/**
 * Exchange rate
 */
struct ExchangeRate {
    std::string from;
    std::string to;
    double rate;
    int64_t timestamp;
};

/**
 * Main Wallet class
 */
class CryptoWallet {
public:
    CryptoWallet();
    ~CryptoWallet();

    // ============================================
    // WALLET MANAGEMENT
    // ============================================

    /**
     * Create new wallet
     * @param password Encryption password
     * @return Recovery phrase (12/24 words)
     */
    std::string createWallet(const std::string& password);

    /**
     * Import wallet from recovery phrase
     * @param mnemonic 12/24 word recovery phrase
     * @param password Encryption password
     * @return Success
     */
    bool importWallet(const std::string& mnemonic, const std::string& password);

    /**
     * Load existing wallet
     * @param password Decryption password
     * @return Success
     */
    bool loadWallet(const std::string& password);

    /**
     * Backup wallet
     * @return Recovery phrase
     */
    std::string backupWallet();

    /**
     * Get wallet addresses
     */
    std::vector<WalletAddress> getAddresses() const;

    /**
     * Get address for blockchain
     */
    std::string getAddress(Blockchain blockchain) const;

    /**
     * Generate new address for blockchain
     */
    std::string generateAddress(Blockchain blockchain);

    // ============================================
    // BALANCE & TRANSACTIONS
    // ============================================

    /**
     * Get balance for blockchain
     */
    Balance getBalance(Blockchain blockchain) const;

    /**
     * Get total balance in USD
     */
    double getTotalBalanceUSD() const;

    /**
     * Get all balances
     */
    std::map<Blockchain, Balance> getAllBalances() const;

    /**
     * Get transactions history
     */
    std::vector<Transaction> getTransactions(Blockchain blockchain, int limit = 50);

    /**
     * Get transaction by hash
     */
    Transaction getTransaction(const std::string& hash) const;

    // ============================================
    // TRANSACTIONS
    // ============================================

    /**
     * Send cryptocurrency
     * @param to Recipient address
     * @param amount Amount to send
     * @param blockchain Blockchain to use
     * @param memo Optional memo/note
     * @return Transaction ID
     */
    std::string send(
        const std::string& to,
        double amount,
        Blockchain blockchain,
        const std::string& memo = "");

    /**
     * Send tokens (ERC20, BEP20, etc.)
     * @param to Recipient address
     * @param amount Amount to send
     * @param token_contract Token contract address
     * @param blockchain Blockchain
     * @return Transaction ID
     */
    std::string sendToken(
        const std::string& to,
        double amount,
        const std::string& token_contract,
        Blockchain blockchain);

    /**
     * Send to Liberty Reach user (by user ID)
     * @param to_user_id Liberty Reach user ID
     * @param amount Amount to send
     * @param blockchain Blockchain to use
     * @param memo Optional memo
     * @return Transaction ID
     */
    std::string sendToUser(
        const std::string& to_user_id,
        double amount,
        Blockchain blockchain,
        const std::string& memo = "");

    /**
     * Estimate transaction fee
     */
    double estimateFee(Blockchain blockchain, double amount = 0.0);

    // ============================================
    // SWAP / EXCHANGE
    // ============================================

    /**
     * Swap tokens (using DEX)
     * @param from_token From token symbol
     * @param to_token To token symbol
     * @param amount Amount to swap
     * @param slippage Slippage tolerance (percent)
     * @return Transaction ID
     */
    std::string swap(
        const std::string& from_token,
        const std::string& to_token,
        double amount,
        double slippage = 0.5);

    /**
     * Get exchange rate
     */
    ExchangeRate getExchangeRate(
        const std::string& from,
        const std::string& to);

    /**
     * Get best swap route
     */
    std::vector<std::map<std::string, std::string>> getSwapRoute(
        const std::string& from,
        const std::string& to,
        double amount);

    // ============================================
    // NFT
    // ============================================

    /**
     * Get NFTs
     */
    std::vector<NFT> getNFTs() const;

    /**
     * Get NFTs for blockchain
     */
    std::vector<NFT> getNFTs(Blockchain blockchain) const;

    /**
     * Transfer NFT
     */
    std::string transferNFT(
        const std::string& to,
        const std::string& nft_id,
        Blockchain blockchain);

    // ============================================
    // STAKING
    // ============================================

    /**
     * Stake tokens
     * @param amount Amount to stake
     * @param blockchain Blockchain
     * @param validator Validator address (optional)
     * @return Transaction ID
     */
    std::string stake(double amount, Blockchain blockchain, const std::string& validator = "");

    /**
     * Unstake tokens
     */
    std::string unstake(double amount, Blockchain blockchain);

    /**
     * Get staking rewards
     */
    double getStakingRewards(Blockchain blockchain) const;

    /**
     * Get staking APY
     */
    double getStakingAPY(Blockchain blockchain) const;

    // ============================================
    // SECURITY
    // ============================================

    /**
     * Lock wallet
     */
    void lock();

    /**
     * Unlock wallet
     */
    bool unlock(const std::string& password);

    /**
     * Check if wallet is unlocked
     */
    bool isUnlocked() const;

    /**
     * Change password
     */
    bool changePassword(const std::string& old_password, const std::string& new_password);

    /**
     * Enable biometric authentication
     */
    bool enableBiometric();

    /**
     * Set transaction PIN
     */
    bool setTransactionPIN(const std::string& pin);

    /**
     * Require PIN for transactions
     */
    void setRequirePIN(bool require);

    // ============================================
    // UTILITIES
    // ============================================

    /**
     * Set callbacks
     */
    void setCallbacks(const WalletCallbacks& callbacks);

    /**
     * Refresh balances and transactions
     */
    void refresh();

    /**
     * Get supported blockchains
     */
    static std::vector<Blockchain> getSupportedBlockchains();

    /**
     * Get blockchain name
     */
    static std::string getBlockchainName(Blockchain blockchain);

    /**
     * Get blockchain symbol
     */
    static std::string getBlockchainSymbol(Blockchain blockchain);

    /**
     * Export private key (DANGEROUS!)
     */
    std::string exportPrivateKey(Blockchain blockchain, const std::string& password);

    /**
     * Import private key
     */
    bool importPrivateKey(const std::string& private_key, Blockchain blockchain, const std::string& password);

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;

    bool encrypted_ = false;
    bool unlocked_ = false;
    WalletCallbacks callbacks_;

    // Internal methods
    void initializeBlockchain(Blockchain blockchain);
    void syncTransactions(Blockchain blockchain);
    std::string signTransaction(const std::string& tx_data, Blockchain blockchain);
    std::string broadcastTransaction(const std::string& signed_tx, Blockchain blockchain);
};

} // namespace wallet
} // namespace liberty_reach
} // namespace td
