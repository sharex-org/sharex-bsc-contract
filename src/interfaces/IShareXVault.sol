// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {
    CountryInfo,
    DeviceInfo,
    DeviceParams,
    MerchantInfo,
    MerchantParams,
    PartnerInfo,
    PartnerParams,
    StatsInfo,
    SystemState,
    TransactionBatch,
    TransactionDetail,
    UploadBatchParams,
    Version
} from "../libraries/DataTypes.sol";

/**
 * @title IShareXVault
 * @dev Interface for the ShareX Vault contract
 */
interface IShareXVault {
    /**
     * @dev Register a new partner
     * @param params Partner registration parameters
     */
    function registerPartner(PartnerParams calldata params) external;

    /**
     * @dev Register a new merchant
     * @param params Merchant registration parameters
     */
    function registerMerchant(MerchantParams calldata params) external;

    /**
     * @dev Register a new device
     * @param params Device registration parameters
     */
    function registerDevice(DeviceParams calldata params) external;

    /**
     * @dev Upload a transaction batch
     * @param params Upload batch parameters
     */
    function uploadTransactionBatch(UploadBatchParams calldata params) external;

    /**
     * @dev Register a country
     * @param iso2 The ISO2 country code
     */
    function registerCountry(string calldata iso2) external;

    /**
     * @dev Toggle maintenance mode
     * @param enabled Whether to enable maintenance mode
     */
    function setMaintenanceMode(bool enabled) external;

    /**
     * @dev Withdraw ETH from the contract
     * @param recipient The recipient address
     * @param amount The amount to withdraw
     */
    function withdrawEth(address payable recipient, uint256 amount) external;

    /**
     * @dev Emergency pause the contract
     */
    function emergencyPause() external;

    /**
     * @dev Unpause the contract
     */
    function unpause() external;

    /**
     * @dev Get the contract version
     * @return version The current version
     */
    function getVersion() external view returns (Version memory);

    /**
     * @dev Get system state information
     * @return state The current system state
     */
    function getSystemState() external view returns (SystemState memory);

    /**
     * @dev Get statistics information
     * @return stats The current statistics
     */
    function getStats() external view returns (StatsInfo memory);

    /**
     * @dev Get partner information by ID
     * @param partnerId The partner ID
     * @return partner The partner information
     */
    function getPartner(uint256 partnerId) external view returns (PartnerInfo memory);

    /**
     * @dev Get partner information by partner code
     * @param partnerCode The partner code
     * @return partner The partner information
     */
    function getPartnerByCode(bytes32 partnerCode) external view returns (PartnerInfo memory);

    /**
     * @dev Check if a partner exists by code
     * @param partnerCode The partner code
     * @return exists Whether the partner exists
     */
    function partnerExists(bytes32 partnerCode) external view returns (bool);

    /**
     * @dev Get merchant information by ID
     * @param merchantId The merchant ID
     * @return merchant The merchant information
     */
    function getMerchant(uint256 merchantId) external view returns (MerchantInfo memory);

    /**
     * @dev Get merchant information by merchant ID
     * @param merchantId The merchant ID (bytes32)
     * @return merchant The merchant information
     */
    function getMerchantById(bytes32 merchantId) external view returns (MerchantInfo memory);

    /**
     * @dev Check if a merchant exists by ID
     * @param merchantId The merchant ID
     * @return exists Whether the merchant exists
     */
    function merchantExists(bytes32 merchantId) external view returns (bool);

    /**
     * @dev Get device information by ID
     * @param deviceId The device ID
     * @return device The device information
     */
    function getDevice(uint256 deviceId) external view returns (DeviceInfo memory);

    /**
     * @dev Get device information by device ID
     * @param deviceId The device ID (bytes32)
     * @return device The device information
     */
    function getDeviceById(bytes32 deviceId) external view returns (DeviceInfo memory);

    /**
     * @dev Check if a device exists by ID
     * @param deviceId The device ID
     * @return exists Whether the device exists
     */
    function deviceExists(bytes32 deviceId) external view returns (bool);

    /**
     * @dev Get transaction batch by ID
     * @param batchId The batch ID
     * @return batch The transaction batch
     */
    function getTransactionBatch(uint256 batchId) external view returns (TransactionBatch memory);

    /**
     * @dev Get transaction details for a batch
     * @param batchId The batch ID
     * @return details The transaction details array
     */
    function getTransactionDetails(uint256 batchId)
        external
        view
        returns (TransactionDetail[] memory);

    /**
     * @dev Get country information
     * @param iso2 The ISO2 country code
     * @return country The country information
     */
    function getCountry(bytes2 iso2) external view returns (CountryInfo memory);

    /**
     * @dev Check if a country is registered
     * @param iso2 The ISO2 country code
     * @return exists Whether the country is registered
     */
    function countryExists(bytes2 iso2) external view returns (bool);
}
