const fs = require('fs');
const ethers = require('ethers');

// Path to the keystore file
const keystorePath = './keystore.json'; // Replace with your keystore file path
const password = 'your-password-here'; // Replace with the actual password

async function decryptKeystore(keystorePath, password) {
  try {
    // Validate inputs
    if (!keystorePath || typeof keystorePath !== 'string' || keystorePath.trim() === '') {
      throw new Error('Invalid or missing keystore file path.');
    }

    if (!password || typeof password !== 'string' || password.trim() === '') {
      throw new Error('Invalid or missing password.');
    }

    // Check if keystore file exists and is readable
    if (!fs.existsSync(keystorePath)) {
      throw new Error(`Keystore file not found at: ${keystorePath}`);
    }

    let keystoreJson;
    try {
      // Read and parse the keystore file
      keystoreJson = fs.readFileSync(keystorePath, 'utf8');
      JSON.parse(keystoreJson); // Validate JSON format
    } catch (error) {
      throw new Error('Invalid keystore file: Not a valid JSON format.');
    }

    // Decrypt the keystore using the password
    const wallet = await ethers.Wallet.fromEncryptedJson(keystoreJson, password);

    // Output the private key and address
    console.log('Private Key:', wallet.privateKey);
    console.log('Address:', wallet.address);
  } catch (error) {
    console.error('Error decrypting keystore:', error.message);
  }
}

// Run the function with validated inputs
decryptKeystore(keystorePath, password);
