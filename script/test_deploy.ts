import { ethers } from 'ethers'
import * as fs from 'fs'
import dotenv from 'dotenv'
import path from 'path'
import { exec } from 'child_process'

dotenv.config({ path: path.resolve(__dirname, '../.env') });

let url: string = process.env.POLYGON_MUMBAI_RPC_URL as string
const provider = ethers.getDefaultProvider(url)

let key: string = process.env.PRIVATE_KEY as string
const wallet = new ethers.Wallet(key)
const signer = wallet.connect(provider)

async function main() {

    const gasPrice = (await provider.getFeeData()).gasPrice
    const chainId: number = parseInt(process.env.CHAIN_ID as string)
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
    const contractTwap = new ethers.Contract(addressTwap, outTwap.abi, signer)
    //                       0xc307c44629779eb8fc0b85f224c3d22f5876a6c84de0ee42d481eb7814f0d3a8
    const oracleAdminRole = "0xc307c44629779eb8fc0b85f224c3d22f5876a6c84de0ee42d481eb7814f0d3a8"
    const txn00 = await contractTwap.grantRole(oracleAdminRole, wallet.address)
    await txn00.wait()

    const intervalUsdc: number = 1800
    const intervalDimo: number = 240
    await contractTwap.initialize(intervalUsdc, intervalDimo)

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

    let providerAdminRole = "0x9d2b5027b19aca88f2f1800508f7464c1461521b1a4fd3efe3ebd10aff8cee19"
    const txn01 = await contractNpp.grantRole(providerAdminRole, wallet.address)
    await txn01.wait()

    await contractNpp.addOracleSource(addressTwap);

    // ******************************************
    // * ====== TEST ONLY - REMOVE ME ========= *
    // ******************************************

    const nameMos = 'MockOracleSource'
    const outMos = JSON.parse(fs.readFileSync(`./out/${nameMos}.sol/${nameMos}.json`, 'utf8')) 
    const factoryMos = new ethers.ContractFactory(outMos.abi, outMos.bytecode.object, signer)
    const mockOracleSource: ethers.BaseContract = await factoryMos.deploy({gasPrice: gasPrice})
    await mockOracleSource.waitForDeployment()
    const addressMos = await mockOracleSource.getAddress()
    console.log(`${nameMos}: ` + addressMos)
    await verifyContractUntilSuccess(addressMos, nameMos, chainId, etherscanApiKey)
    /* * */
    const transaction = await contractNpp.addOracleSource(addressMos);
    await transaction.wait();
    const primaryOracleSourceIndex = 1;
    await contractNpp.setPrimaryOracleSource(primaryOracleSourceIndex);

    // ********************************
    // * ====== DIMO Credit ========= *
    // ********************************

    const addressReceiver = '0x2332A085461391595C3127472046EDC39996e141';

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


    // ******************************************
    // * ====== TEST ONLY - REMOVE ME ========= *
    // ******************************************

    const nameTt = 'TestToken'
    const outTt = JSON.parse(fs.readFileSync(`./out/${nameTt}.sol/${nameTt}.json`, 'utf8')) 
    const factoryTt = new ethers.ContractFactory(outTt.abi, outTt.bytecode.object, signer)
    const testToken: ethers.BaseContract = await factoryTt.deploy({gasPrice: gasPrice})
    await testToken.waitForDeployment()
    const addressTt = await testToken.getAddress()
    console.log(`${nameTt}: ` + addressTt)
    await verifyContractUntilSuccess(addressTt, nameTt, chainId, etherscanApiKey)

    // ********************************
    // * ====== Dev License ========= *
    // ********************************
    
    const licenseCostInUsd = BigInt("1000000000000000000")

    const nameDl = 'DevLicenseDimo';
    const outDl = JSON.parse(fs.readFileSync(`./out/${nameDl}.sol/${nameDl}.json`, 'utf8')) 
    const factoryDl = new ethers.ContractFactory(outDl.abi, outDl.bytecode.object, signer)
    const devLicense: ethers.BaseContract = await factoryDl.deploy(
        addressReceiver,
        addressLaf,
        addressNpp,
        addressTt,
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
        addressTt,
        addressDc,
        licenseCostInUsd
    ])
    await verifyContractUntilSuccess(addressDl, nameDl, chainId, etherscanApiKey, encodeArgsDl)

    /* * */
    const contractLaf = new ethers.Contract(addressLaf, outLaf.abi, signer)
    await contractLaf.setLicense(addressDl)
    /* * */
    const contractTt = new ethers.Contract(addressTt, outTt.abi, signer)
    const value = 1000000000000000000000000n
    await contractTt.approve(addressDl, value)


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



