// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.24;

import {ShareXVault} from "../src/ShareXVault.sol";
import {
    DeviceParams,
    MerchantParams,
    PartnerParams,
    TransactionBatch,
    TransactionDetail,
    UploadBatchParams
} from "../src/libraries/DataTypes.sol";
import {
    EmptyTransactionDetails,
    EntityNotFound,
    OrderCountMismatch,
    TooManyTransactionDetails
} from "../src/libraries/Errors.sol";
import {Test} from "forge-std/Test.sol";

contract ShareXVaultTransactionTest is Test {
    // ================================================================
    // Constants
    // ================================================================

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // ================================================================
    // State Variables
    // ================================================================

    ShareXVault public vault;

    address public admin = makeAddr("admin");
    address public operator = makeAddr("operator");
    address public user = makeAddr("user");

    event TransactionBatchUploaded(
        uint256 indexed batchId,
        bytes32 indexed deviceId,
        uint32 orderCount,
        uint256 totalAmount,
        uint256 dateComparable,
        uint256 timestamp
    );

    event TransactionDetailsUploaded(
        uint256 indexed batchId, uint256 detailsCount, uint256 timestamp
    );

    function setUp() public {
        vault = new ShareXVault(admin);

        vm.startPrank(admin);
        vault.grantRole(OPERATOR_ROLE, operator);
        vm.stopPrank();

        // Register dependencies for transaction tests
        _registerTestPartner();
        _registerTestMerchant();
        _registerTestDevice();
    }

    function testUploadTransactionBatchSuccess() public {
        UploadBatchParams memory params = _createValidUploadBatchParams();
        bytes32 expectedDeviceId = keccak256(abi.encodePacked(params.deviceId));

        vm.expectEmit(true, true, false, true);
        emit TransactionBatchUploaded(
            1,
            expectedDeviceId,
            params.orderCount,
            params.totalAmount,
            params.dateComparable,
            block.timestamp
        );

        vm.expectEmit(true, false, false, true);
        emit TransactionDetailsUploaded(1, 2, block.timestamp);

        vm.prank(operator);
        vault.uploadTransactionBatch(params);

        // Verify transaction batch was created
        TransactionBatch memory batch = vault.getTransactionBatch(1);
        assertEq(batch.id, 1);
        assertEq(batch.basicInfo.deviceId, expectedDeviceId);
        assertEq(batch.basicInfo.orderCount, params.orderCount);
        assertEq(batch.basicInfo.totalAmount, params.totalAmount);
        assertEq(batch.basicInfo.dateComparable, params.dateComparable);
        assertEq(batch.batchTimestamp, block.timestamp);

        // Verify transaction details were stored
        TransactionDetail[] memory details = vault.getTransactionDetails(1);
        assertEq(details.length, 2);
        assertEq(details[0].userId, keccak256("USER001"));
        assertEq(details[0].sharexId, keccak256("SHAREX001"));
        assertEq(details[0].itemCount, 3);
        assertEq(details[1].userId, keccak256("USER002"));
        assertEq(details[1].sharexId, keccak256("SHAREX002"));
        assertEq(details[1].itemCount, 1);
    }

    function testUploadTransactionBatchEmptyTransactionDetails() public {
        UploadBatchParams memory params = _createValidUploadBatchParams();
        params.transactionDetails = new TransactionDetail[](0);
        params.orderCount = 0;

        vm.prank(operator);
        vm.expectRevert(EmptyTransactionDetails.selector);
        vault.uploadTransactionBatch(params);
    }

    function testUploadTransactionBatchOrderCountMismatch() public {
        UploadBatchParams memory params = _createValidUploadBatchParams();
        params.orderCount = 5; // Mismatch with actual count of 2

        vm.prank(operator);
        vm.expectRevert(OrderCountMismatch.selector);
        vault.uploadTransactionBatch(params);
    }

    function testUploadTransactionBatchDeviceNotFound() public {
        UploadBatchParams memory params = _createValidUploadBatchParams();
        params.deviceId = "NONEXISTENT_DEVICE";

        bytes32 deviceId = keccak256(abi.encodePacked(params.deviceId));

        vm.prank(operator);
        vm.expectRevert(abi.encodeWithSelector(EntityNotFound.selector, "device", deviceId));
        vault.uploadTransactionBatch(params);
    }

    function testUploadTransactionBatchTooManyTransactionDetails() public {
        // Create batch with 1001 transaction details (exceeds max of 1000)
        TransactionDetail[] memory largeDetails = new TransactionDetail[](1001);
        for (uint256 i = 0; i < 1001; i++) {
            largeDetails[i] = TransactionDetail({
                userId: keccak256(abi.encodePacked("USER", i)),
                sharexId: keccak256(abi.encodePacked("SHAREX", i)),
                transactionAmount: keccak256(abi.encodePacked(uint256(100))),
                itemCount: 1,
                timestamp: 1700000000 + i,
                additionalData: "{}"
            });
        }

        UploadBatchParams memory params = UploadBatchParams({
            deviceId: "DEVICE001",
            dateComparable: 20231115,
            orderCount: 1001,
            totalAmount: 100100,
            transactionDetails: largeDetails
        });

        vm.prank(operator);
        vm.expectRevert(TooManyTransactionDetails.selector);
        vault.uploadTransactionBatch(params);
    }

    // ================================================================
    // Internal Helper Functions
    // ================================================================

    function _registerTestPartner() internal {
        PartnerParams memory partnerParams = PartnerParams({
            partnerCode: "PARTNER001",
            partnerName: "Test Partner",
            iso2: "US",
            verification: "VER123",
            description: "Test Description",
            businessType: "Retail"
        });

        vm.prank(operator);
        vault.registerPartner(partnerParams);
    }

    function _registerTestMerchant() internal {
        MerchantParams memory merchantParams = MerchantParams({
            merchantName: "Test Merchant",
            merchantId: "MERCHANT001",
            description: abi.encodePacked("Test merchant description"),
            iso2: "US",
            locationId: "NYC001",
            location: "New York City",
            merchantType: "Retail",
            verification: "VER123"
        });

        vm.prank(operator);
        vault.registerMerchant(merchantParams);
    }

    function _registerTestDevice() internal {
        DeviceParams memory deviceParams = DeviceParams({
            deviceId: "DEVICE001",
            deviceType: "POS_TERMINAL",
            partnerCode: "PARTNER001",
            merchantId: "MERCHANT001"
        });

        vm.prank(operator);
        vault.registerDevice(deviceParams);
    }

    function _createValidUploadBatchParams() internal pure returns (UploadBatchParams memory) {
        TransactionDetail[] memory details = new TransactionDetail[](2);
        details[0] = TransactionDetail({
            userId: keccak256("USER001"),
            sharexId: keccak256("SHAREX001"),
            transactionAmount: keccak256(abi.encodePacked(uint256(150))),
            itemCount: 3,
            timestamp: 1700000000,
            additionalData: "{\"category\": \"food\", \"payment\": \"card\"}"
        });
        details[1] = TransactionDetail({
            userId: keccak256("USER002"),
            sharexId: keccak256("SHAREX002"),
            transactionAmount: keccak256(abi.encodePacked(uint256(75))),
            itemCount: 1,
            timestamp: 1700000001,
            additionalData: "{\"category\": \"beverage\", \"payment\": \"cash\"}"
        });

        return UploadBatchParams({
            deviceId: "DEVICE001",
            dateComparable: 20231115,
            orderCount: 2,
            totalAmount: 225,
            transactionDetails: details
        });
    }
}
