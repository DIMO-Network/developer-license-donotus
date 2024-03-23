import { ethers } from 'ethers'
import * as fs from 'fs'
import dotenv from 'dotenv'
import path from 'path'
import { exec } from 'child_process'

dotenv.config({ path: path.resolve(__dirname, '../.env') });

let url: string = process.env.POLYGON_MAINNET_RPC_URL as string
const provider = ethers.getDefaultProvider(url)

let key: string = process.env.PRIVATE_KEY as string
const wallet = new ethers.Wallet(key)
const signer = wallet.connect(provider)

async function main() {

    const gasPrice = (await provider.getFeeData()).gasPrice
    const chainId: number = parseInt(process.env.MAIN_CHAIN_ID as string)
    const etherscanApiKey: string = process.env.ETHERSCAN_API_KEY_POLYGON as string

    // ***************************
    // * ====== Oracle ========= *
    // ***************************

    const nameTwap = 'TwapV3'
    const outTwap = JSON.parse(fs.readFileSync(`./out/${nameTwap}.sol/${nameTwap}.json`, 'utf8')) 
    const setTwap = new ethers.ContractFactory(outTwap.abi, outTwap.bytecode.object, signer)
    const twap = await setTwap.deploy({gasPrice: gasPrice})
    await twap.waitForDeployment()
    const addressTwap = await twap.getAddress()
    console.log(`${nameTwap}: ` + addressTwap)
    await verifyContractUntilSuccess(addressTwap, nameTwap, chainId, etherscanApiKey)
    /* * */

    const nameNpp = 'NormalizedPriceProvider'
    const outNpp = JSON.parse(fs.readFileSync(`./out/${nameNpp}.sol/${nameNpp}.json`, 'utf8')) 
    const setNpp = new ethers.ContractFactory(outNpp.abi, outNpp.bytecode.object, signer)
    const normalizedPriceProvider = await setNpp.deploy({gasPrice: gasPrice})
    await normalizedPriceProvider.waitForDeployment()
    const addressNpp = await normalizedPriceProvider.getAddress()
    console.log(`${nameNpp}: ` + addressNpp);
    await verifyContractUntilSuccess(addressNpp, nameNpp, chainId, etherscanApiKey)
    /* * */
    const contractNpp = new ethers.Contract(addressNpp, outNpp.abi, signer)
    const providerAdminRole = "0x9d2b5027b19aca88f2f1800508f7464c1461521b1a4fd3efe3ebd10aff8cee19"
    const txn0x = await contractNpp.grantRole(providerAdminRole, signer.address)
    await txn0x.wait()
    await contractNpp.addOracleSource(addressTwap)

    // ********************************
    // * ====== DIMO Credit ========= *
    // ********************************

    const addressReceiver = '0xA2f0fD6A9411f4911b992C2389A53FfAb1E2BE88';

    const nameDc = 'DimoCredit';
    const outDc = JSON.parse(fs.readFileSync(`./out/${nameDc}.sol/${nameDc}.json`, 'utf8')) 
    const factoryDc = new ethers.ContractFactory(outDc.abi, outDc.bytecode.object, signer)
    const dimoCredit: ethers.BaseContract = await factoryDc.deploy(addressReceiver, addressNpp, {gasPrice: gasPrice})
    await dimoCredit.waitForDeployment()
    const addressDc = await dimoCredit.getAddress()
    console.log(`${nameDc}: ` + addressDc);
    let encodeArgsDc = factoryDc.interface.encodeDeploy([addressReceiver, addressNpp])
    await verifyContractUntilSuccess(addressDc, nameDc, chainId, etherscanApiKey, encodeArgsDc)

    // ********************************************
    // * ====== License Account Factory ========= *
    // ********************************************

    const nameLaf = 'LicenseAccountFactory';
    const outLaf = JSON.parse(fs.readFileSync(`./out/${nameLaf}.sol/${nameLaf}.json`, 'utf8')) 
    const factoryLaf = new ethers.ContractFactory(outLaf.abi, outLaf.bytecode.object, signer)
    const licenseAccountFactory: ethers.BaseContract = await factoryLaf.deploy({gasPrice: gasPrice})
    await licenseAccountFactory.waitForDeployment();
    const addressLaf = await licenseAccountFactory.getAddress();
    console.log(`${nameLaf}: ` + addressLaf);
    await verifyContractUntilSuccess(addressLaf, nameLaf, chainId, etherscanApiKey)

    // ********************************
    // * ====== Dev License ========= *
    // ********************************

    const licenseCostInUsd = BigInt("1000000000000000000")
    const addressDimoToken = "0xE261D618a959aFfFd53168Cd07D12E37B26761db"

    const nameDl = 'DevLicenseDimo';
    const outDl = JSON.parse(fs.readFileSync(`./out/${nameDl}.sol/${nameDl}.json`, 'utf8')) 
    const factoryDl = new ethers.ContractFactory(outDl.abi, outDl.bytecode.object, signer)
    const devLicense: ethers.BaseContract = await factoryDl.deploy(
        addressReceiver,
        addressLaf,
        addressNpp,
        addressDimoToken,
        addressDc,
        licenseCostInUsd,
        {
            maxPriorityFeePerGas: (await provider.getFeeData()).maxPriorityFeePerGas,
            maxFeePerGas: (await provider.getFeeData()).maxFeePerGas,
        }
    )
    await devLicense.waitForDeployment();
    const addressDl = await devLicense.getAddress();
    console.log(`${nameDl}: ` + addressDl);
    let encodeArgsDl = factoryDl.interface.encodeDeploy([
        addressReceiver,
        addressLaf,
        addressNpp,
        addressDimoToken,
        addressDc,
        licenseCostInUsd
    ])
    await verifyContractUntilSuccess(addressDl, nameDl, chainId, etherscanApiKey, encodeArgsDl)

    /* * */
    const contractLaf = new ethers.Contract(addressLaf, outLaf.abi, signer)
    await contractLaf.setLicense(addressDl)
    /* * */

    process.exit();
}



async function verifyContractUntilSuccess(address: any, name: any, chainId: any, apiKey: any, arg?: any) {
    return new Promise((resolve, _) => {

        let command: string;
        if(!arg) {
            command = `forge verify-contract ${address} ${name} --chain-id ${chainId} --etherscan-api-key ${apiKey}`;
        } else {
            command = `forge verify-contract ${address} ${name} --chain-id ${chainId} --etherscan-api-key ${apiKey} --constructor-args ${arg}`;
        }

        const attemptVerification = () => {
            exec(command, (error, stdout, stderr) => {
                if (error) {
                    console.error(`exec error: ${error}`);
                    setTimeout(attemptVerification, 1000); // Try again after 1 second
                    return;
                }
                // stdout contains the output of the command
                let output = stdout;
                console.log(`Output: ${output}`);
                if (stderr) {
                    console.error(`stderr: ${stderr}`);
                }
                // Check if the output indicates success
                if (output.includes("OK")) {
                    resolve(output);
                    return;
                } else {
                    setTimeout(attemptVerification, 1000); // Try again after 1 second
                }
            });
        };
        attemptVerification();
    });
}
    
main();



