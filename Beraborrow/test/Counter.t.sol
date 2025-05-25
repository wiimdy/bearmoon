// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";
import {IMetaBeraborrowCore} from "src/interfaces/core/IMetaBeraborrowCore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDebtToken} from "src/interfaces/core/IDebtToken.sol";
import {PermissionlessPSM} from "src/core/PermissionlessPSM.sol";

contract CounterTest is Test {
    Counter public counter;

    function setUp() public {
        counter = new Counter();
        counter.setNumber(0);
    }

    // function test_Increment() public {
    //     counter.increment();
    //     assertEq(counter.number(), 1);
    // }
    // function test_getPeripheryFlashLoanFee() public {
    //     uint16 newFee = 1; // 0.05% --> 0.01%
    //     address periphery = makeAddr("periphery");

    //     IMetaBeraborrowCore metaBeraborrowCore = IMetaBeraborrowCore(
    //         0x27393e8a6f8f2e32B870903279999C820E984DC7
    //     ); // 실제 주소로 설정 필요
    //     address owner = metaBeraborrowCore.owner();
    //     address nectarToken = (metaBeraborrowCore.nect()); // nect 토큰 주소 가져오기

    //     vm.prank(owner);
    //     metaBeraborrowCore.setPeripheryFlashLoanFee(periphery, newFee, true);

    //     vm.prank(periphery);
    //     uint fee = IDebtToken((nectarToken)).flashFee((nectarToken), 1e4);

    //     assertEq(fee, 5);
    // }
    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }

    // --- PermissionlessPSM redeem 테스트 ---
    function test_PermissionlessPSM_redeem() public {
        IMetaBeraborrowCore metaBeraborrowCore = IMetaBeraborrowCore(
            0x27393e8a6f8f2e32B870903279999C820E984DC7
        ); // 실제 주소로 설정 필요
        // address owner = metaBeraborrowCore.owner();
        address nect = (metaBeraborrowCore.nect()); // nect 토큰 주소 가져오기
        PermissionlessPSM psm = PermissionlessPSM(
            0xB2F796FA30A8512C1D27a1853a9a1a8056b5CC25
        );

        address receiver = 0x00000000F2708738d4886Bc4aEdEFd8dD04818b0;

        uint256 initialNect = IERC20(nect).balanceOf(address(receiver));

        vm.prank(0x00000000F2708738d4886Bc4aEdEFd8dD04818b0);
        // nect.mint(address(this), initialNect);
        IERC20(nect).approve(address(psm), 1 ether);
        address stable = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
        // 3. redeem 테스트 실행
        uint256 redeemAmount = 1 ether;
        uint16 maxFeePercentage = 100; // 1% 예시
        // PSM 컨트랙트에 NECT를 소각할 수 있도록 balance를 맞춰줌
        vm.prank(0x00000000F2708738d4886Bc4aEdEFd8dD04818b0);

        psm.redeem(address(stable), redeemAmount, receiver, maxFeePercentage);

        // 4. 결과 검증 (수수료는 previewRedeem 로직에 따라 다름)
        // receiver가 stable을 받았는지 확인
        assertGt(IERC20(stable).balanceOf(receiver), 0);
        // 내 NECT 잔고가 줄었는지 확인
        assertEq(
            IERC20(nect).balanceOf(address(receiver)),
            initialNect - redeemAmount
        );
    }
}
