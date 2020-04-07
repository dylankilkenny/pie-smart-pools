// This way of importing is a bit funky. We should fix this in the Mock Contracts package
import { MockTokenFactory } from "@pie-dao/mock-contracts/dist/typechain/MockTokenFactory";
import { MockKyberNetworkFactory } from "@pie-dao/mock-contracts/dist/typechain/MockKyberNetworkFactory";
import { MockToken } from "@pie-dao/mock-contracts/typechain/MockToken";
import { MockKyberNetwork } from "@pie-dao/mock-contracts/typechain/MockKyberNetwork";
import { ethers } from "@nomiclabs/buidler";
import { Signer, Wallet, utils, constants } from "ethers";
import { BigNumber } from "ethers/utils";
import chai from "chai";
import { deployContract, solidity } from "ethereum-waffle";

import { deployBalancerPool, deployUniswapFactory, deployAndAddLiquidityUniswapExchange } from "../utils";
import { IBPool } from "../typechain/IBPool";
import { IBPoolFactory } from "../typechain/IBPoolFactory";
import { PBasicSmartPool } from "../typechain/PBasicSmartPool";
import PBasicSmartPoolArtifact from "../artifacts/PBasicSmartPool.json";
import { PSingleAssetJoinExitRecipe } from "../typechain/PSingleAssetJoinExitRecipe";
import PSingleAssetJoinExitRecipeArtifact from "../artifacts/PSingleAssetJoinExitRecipe.json";
import { IUniswapFactory } from "../typechain/IUniswapFactory";
import { WeiPerEther } from "ethers/constants";


chai.use(solidity);
const { expect } = chai;

const PLACE_HOLDER_ADDRESS = "0x1200000000000000000000000000000000000001";
const ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
const NAME = "TEST POOL";
const SYMBOL = "TPL";
const INITIAL_SUPPLY = constants.WeiPerEther;

describe.only("PSingleAssetJoinExitRecipe", function() {
    this.timeout(300000);
    let signers: Signer[];
    let account: string;
    let account2: string;
    let tokens: MockToken[];
    let pool: IBPool;
    let smartpool: PBasicSmartPool;
    let recipe: PSingleAssetJoinExitRecipe;

    beforeEach(async() => {
        signers = await ethers.signers();
        account = await signers[0].getAddress();
        account2 = PLACE_HOLDER_ADDRESS;

        pool = IBPoolFactory.connect((await deployBalancerPool(signers[0])), signers[0]);

        const tokenFactory = new MockTokenFactory(signers[0]);
        tokens = [];

        for(let i = 0; i < 3; i ++) {
            const token: MockToken = (await tokenFactory.deploy(`Mock ${i}`, `M${i}`, 18));
            await token.mint(account, constants.WeiPerEther.mul(1000000));
            // await token.mint(await signers[1].getAddress(), constants.WeiPerEther.mul(1000000));
            await token.approve(pool.address, constants.MaxUint256);
            await pool.bind(token.address, constants.WeiPerEther, constants.WeiPerEther.mul(1));
            tokens.push(token);
            console.log(token.address);
        }

        // Deploy this way to get the coverage provider to pick it up
        smartpool = await deployContract(signers[0] as Wallet, PBasicSmartPoolArtifact, [], {gasLimit: 8000000}) as PBasicSmartPool
        await smartpool.init(pool.address, NAME, SYMBOL, INITIAL_SUPPLY);
        await smartpool.approveTokens();
        await pool.setPublicSwap(true);
        await pool.setController(smartpool.address);

        for(const token of tokens) {
            await token.approve(smartpool.address, constants.MaxUint256);
        }

        recipe = await deployContract(signers[0] as Wallet, PSingleAssetJoinExitRecipeArtifact, [smartpool.address]) as PSingleAssetJoinExitRecipe;
        // console.log(await recipe.pool());
        // process.exit();

        // approve contract
        await smartpool.approve(recipe.address, constants.MaxUint256);
    });

    it("Just works", async() => {
        console.log("kek");
        await tokens[0].approve(recipe.address, constants.MaxUint256);
        await recipe.joinswapExternAmountIn(tokens[0].address, constants.WeiPerEther.div(2), constants.One);
    })

    
    
});