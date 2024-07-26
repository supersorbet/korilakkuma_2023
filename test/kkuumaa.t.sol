// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/Korilakkuma.sol";

contract KorilakkumaTest is Test {
    Korilakkuma public korilakkuma;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        vm.startPrank(owner);
        korilakkuma = new Korilakkuma();
        vm.stopPrank();
    }

    function testInitialSupply() public {
        assertEq(korilakkuma.totalSupply(), 69000000 * 10**18);
    }

    function testTransfer() public {
        uint256 amount = 1000 * 10**18;
        vm.prank(owner);
        korilakkuma.transfer(user1, amount);
        assertEq(korilakkuma.balanceOf(user1), amount);
    }

    function testApproveAndTransferFrom() public {
        uint256 amount = 1000 * 10**18;
        vm.startPrank(owner);
        korilakkuma.approve(user1, amount);
        vm.stopPrank();

        vm.prank(user1);
        korilakkuma.transferFrom(owner, user2, amount);
        assertEq(korilakkuma.balanceOf(user2), amount);
    }

    function testStaking() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Transfer some tokens to user1 for staking
        vm.prank(owner);
        korilakkuma.transfer(user1, stakeAmount);

        // User1 stakes tokens
        vm.startPrank(user1);
        korilakkuma.approve(address(korilakkuma), stakeAmount);
        korilakkuma.StakeSingleSlices(stakeAmount, address(0));
        vm.stopPrank();

        // Check staked balance
        (uint256 stakedBalance,,,,,,,,) = korilakkuma.farmer(user1);
        assertEq(stakedBalance, stakeAmount);

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Calculate and check rewards
        uint256 rewards = korilakkuma.calcStakingRewards(user1);
        assertGt(rewards, 0);

        // User1 claims rewards
        vm.prank(user1);
        korilakkuma.ClaimStakeInterest();

        // Check that rewards were received
        assertGt(korilakkuma.balanceOf(user1), 0);

        // User1 unstakes tokens
        vm.prank(user1);
        korilakkuma.UnstakeTokens();

        // Check that tokens were unstaked
        (stakedBalance,,,,,,,,) = korilakkuma.farmer(user1);
        assertEq(stakedBalance, 0);
    }

    function testFailUnauthorizedUnstake() public {
        uint256 stakeAmount = 1000 * 10**18;
        
        // Transfer some tokens to user1 for staking
        vm.prank(owner);
        korilakkuma.transfer(user1, stakeAmount);

        // User1 stakes tokens
        vm.startPrank(user1);
        korilakkuma.approve(address(korilakkuma), stakeAmount);
        korilakkuma.StakeSingleSlices(stakeAmount, address(0));
        vm.stopPrank();

        // User2 tries to unstake User1's tokens
        vm.prank(user2);
        korilakkuma.UnstakeTokens();
    }

    function testLPStaking() public {

        address mockLPToken = address(0x3);
        uint256 lpIndex = 0;

        // Setup mock LP token in Korilakkuma contract
        vm.prank(owner);
        korilakkuma.setPoolActive(mockLPToken, true, 100); // 1% unstake fee

        // User1 stakes LP tokens
        vm.prank(user1);
        vm.mockCall(
            mockLPToken,
            abi.encodeWithSelector(IERC20.transferFrom.selector),
            abi.encode(true)
        );
        korilakkuma.stakeLP(1000 * 10**18, lpIndex, address(0));

        // Check staked LP balance
        assertGt(korilakkuma.stakedLPBalances(user1, lpIndex), 0);

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // User1 harvests Korilakkuma rewards
        vm.prank(user1);
        korilakkuma.HarvestKorilakkuma(lpIndex);

        // Check that rewards were received
        assertGt(korilakkuma.balanceOf(user1), 0);

        // User1 unstakes LP tokens
        vm.prank(user1);
        vm.mockCall(
            mockLPToken,
            abi.encodeWithSelector(IERC20.transfer.selector),
            abi.encode(true)
        );
        korilakkuma.unstakeLP(lpIndex);

        // Check that LP tokens were unstaked
        assertEq(korilakkuma.stakedLPBalances(user1, lpIndex), 0);
    }
}
