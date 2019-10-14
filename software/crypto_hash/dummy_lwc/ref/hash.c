/*   
     dummy1_lw hash

     Implemented by Michael Tempelmeier 
*/   


#define CRYPTO_BYTES 32

//hash a message
int crypto_hash(
	unsigned char *out,
	const unsigned char *in,
	unsigned long long inlen
)
{
	unsigned long long i; 
	unsigned char state[CRYPTO_BYTES]; 

	//initialize the state as constants  
	for (i = 0; i < CRYPTO_BYTES; i++) state[i] = 0;  


	//process the message  
	for (i = 0; i < inlen; i++) 
	{   
		state[i%CRYPTO_BYTES] ^= ((unsigned char*)in)[i]; 
	}

	//padding
	if (inlen%CRYPTO_BYTES != 0)
	{
		state[inlen%CRYPTO_BYTES] = 0x80 ^ state[inlen%CRYPTO_BYTES];
	}

	//finalization stage  
	for (i = 0; i < CRYPTO_BYTES; i++)  
	{
		((unsigned char*)out)[i] = state[i];
	}

	return 0;
}

