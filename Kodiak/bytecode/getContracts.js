const { ethers } = require('ethers');
const fs = require('fs');

const contracts = {
    'UniswapV3Factory': '0xD84CBf0B02636E7f53dB9E5e45A616E05d710990',
    'UniswapV2Factory': '0x5e705e184d233ff2a7cb1553793464a9d0c3028f',
    'NonfungiblePositionManager': '0xFE5E8C83FFE4d9627A75EaA7Fee864768dB989bD',
    'SwapRouter': '0xEd158C4b336A6FCb5B193A5570e3a571f6cbe690',
    'SwapRouter02': '0xe301E48F77963D3F7DbD2a4796962Bd7f3867Fb4',
    'UniswapV2Router02': '0xd91dd58387Ccd9B66B390ae2d7c66dBD46BC6022',
    'QuoterV2': '0x644C8D6E501f7C994B74F5ceA96abe65d0BA662B',
    'MixedRouteQuoterV1': '0xfa0276F06161cC2f66Aa51f3500484EdF8Fc94bB',
    'TickLens': '0xa73C6F1FeC76D5487dC30bdB8f11d1F390394b48',
    'Multicall': '0x89ff70257bc747F310bB538eeFC46aDD763e75d8',
    'Multicall3': '0xcA11bde05977b3631167028862bE2a173976CA11',
    'KodiakIslandFactory': '0x5261c5A5f08818c08Ed0Eb036d9575bA1E02c1d6',
    'KodiakIslandRouter': '0x679a7C63FC83b6A4D9C1F931891d705483d4791F',
    'KodiakIsland': '0xCFe9Ee61c271fBA4D190498b5A71B8CB365a3590',
    'KodiakFarmFactory': '0xAeAa563d9110f833FA3fb1FF9a35DFBa11B0c9cF',
    'KodiakFarm': '0xEB81a9EEAF156d4Cfec2AF364aF36Ad65cF9f0fa',
    'xKDK': '0xe8D7b965BA082835EA917F2B173Ff3E035B69eeB',
    'PandaFactory': '0xac335fe675699b0ce4c927bdaa572eb647ed9f02'
};

async function main() {
    const provider = new ethers.providers.JsonRpcProvider('https://rpc.berachain.com');
    
    for (const [name, address] of Object.entries(contracts)) {
        try {
            const code = await provider.getCode(address);
            fs.writeFileSync(`./${name}.json`, JSON.stringify({
                name,
                address,
                bytecode: code
            }, null, 2));
            console.log(`Saved ${name} contract code`);
        } catch (error) {
            console.error(`Error fetching ${name}:`, error);
        }
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 