/* 
 * Dummy AEAD cipher 
 */

#include "api.h"
#include <stdio.h>


static void printState(const unsigned char *str, const unsigned char *s)
{
  int i;
  printf("%s", str);
  for (i=0; i<16; i++)
  {
    printf("%02X", s[i]);
    if ((i+1)%8 == 0) printf(" ");
  }
  printf("\n");
}

static void store32(unsigned char *x,unsigned long long u)
{
  int i;
  for (i = 3;i >= 0;--i) { x[i] = u; u >>= 8; }
}

static void store64(unsigned char *x,unsigned long long u)
{
  int i;
  for (i = 7;i >= 0;--i) { x[i] = u; u >>= 8; }
}

static int crypto_verify_16(const unsigned char *x,const unsigned char *y)
{
  unsigned int differentbits = 0;
#define F(i) differentbits |= x[i] ^ y[i];
  F(0)
  F(1)
  F(2)
  F(3)
  F(4)
  F(5)
  F(6)
  F(7)
  F(8)
  F(9)
  F(10)
  F(11)
  F(12)
  F(13)
  F(14)
  F(15)
  return (1 & ((differentbits - 1) >> 8)) - 1;
}



int crypto_aead_encrypt(
  unsigned char *c,unsigned long long *clen,
  const unsigned char *m,unsigned long long mlen,
  const unsigned char *ad,unsigned long long adlen,
  const unsigned char *nsec,
  const unsigned char *npub,
  const unsigned char *k
)
{
  unsigned char lenblock[16];
  unsigned char init[16];
  unsigned char block[16];
  unsigned char accum[16];
  unsigned long long blockno = 1;
  unsigned long long blocklen = 16;
  unsigned long long i;

  store64(lenblock,8 * adlen);
  store64(lenblock + 8,8 * mlen);
  *clen = mlen + 16;

  for (i = 0;i < CRYPTO_KEYBYTES;++i)  init[i] =  k[i];
  for (i = 0;i < CRYPTO_NPUBBYTES;++i) init[i] ^= npub[i];
  for (i = 0;i < 16;++i) accum[i] = 0;
  for (i = 0;i < 16;++i) block[i] = 0;

#if DBG
  printf("Encrypt: AD!\n");
#endif

  store32(block + 12,blockno);

  blocklen = REF_A_BLOCK_LEN;
  while (adlen > 0) {
    if (adlen < blocklen) blocklen = adlen;
    for (i = 0;i < blocklen;++i) accum[i] = ad[i] ^ accum[i];
    // Add padding if needed
    if (blocklen < REF_A_BLOCK_LEN) accum[blocklen] = 0x80 ^ accum[blocklen];
    ad += blocklen;
    adlen -= blocklen;
  }

#if DBG
  printf("Encrypt: Data!\n");
#endif

  blocklen = REF_D_BLOCK_LEN;
  while (mlen > 0) {
    if (mlen < blocklen) blocklen = mlen;
    for (i = 0;i < blocklen;++i) c[i]     = m[i] ^ block[i] ^ init[i];
    for (i = 0;i < blocklen;++i) accum[i] = m[i] ^ accum[i];
    // Add padding if needed
    if (blocklen < REF_D_BLOCK_LEN) accum[blocklen] = 0x80 ^ accum[blocklen];

    ++blockno;
    store32(block + 12,blockno);
    c += blocklen;
    m += blocklen;
    mlen -= blocklen;
  }
#if DBG
  printf("Encrypt: Done!\n");

  printState("Lenblock: ", lenblock);
  printState("Init    : ", init);
  printState("Accum   : ", accum);
#endif

  for (i = 0;i < CRYPTO_ABYTES;++i) c[i] = lenblock[i] ^ accum[i] ^ init[i];
  return 0;
}

int crypto_aead_decrypt(
  unsigned char *m,unsigned long long *outputmlen,
  unsigned char *nsec,
  const unsigned char *c,unsigned long long clen,
  const unsigned char *ad,unsigned long long adlen,
  const unsigned char *npub,
  const unsigned char *k
)
{
  unsigned char lenblock[16];
  unsigned char init[16];
  unsigned char block[16];
  unsigned char accum[16];
  unsigned char tag[16];
  unsigned long long blockno = 1;
  unsigned long long blocklen = 16;
  unsigned long long i;

  *outputmlen = clen - CRYPTO_ABYTES;
  clen = clen - CRYPTO_ABYTES;

  store64(lenblock,8 * adlen);
  store64(lenblock + 8,8 * clen);


  for (i = 0;i < CRYPTO_KEYBYTES;++i)  init[i] =  k[i];
  for (i = 0;i < CRYPTO_NPUBBYTES;++i) init[i] ^= npub[i];
  for (i = 0;i < 16;++i) accum[i] = 0;
  for (i = 0;i < 16;++i) block[i] = 0;

  store32(block + 12,blockno);

#if DBG
  printf("Decrypt: AD!\n");
#endif

  blocklen = REF_A_BLOCK_LEN;
  while (adlen > 0) {
    if (adlen < blocklen) blocklen = adlen;
    for (i = 0;i < blocklen;++i) accum[i] = ad[i] ^ accum[i];
    // Add padding if needed
    if (blocklen < REF_A_BLOCK_LEN) accum[blocklen] = 0x80 ^ accum[blocklen];
    ad += blocklen;
    adlen -= blocklen;
  }

#if DBG

  printf("Decrypt: Data!\n");
#endif

  blocklen = REF_D_BLOCK_LEN;
  while (clen > 0) {
    if (clen < blocklen) blocklen = clen;
    for (i = 0;i < blocklen;++i) m[i]     = c[i] ^ block[i] ^ init[i];
    for (i = 0;i < blocklen;++i) accum[i] = m[i] ^ accum[i];
    // Add padding if needed
    if (blocklen < REF_D_BLOCK_LEN) accum[blocklen] = 0x80 ^ accum[blocklen];


    ++blockno;
    store32(block + 12,blockno);
    c += blocklen;
    m += blocklen;
    clen -= blocklen;
  }

#if DBG
  printf("Decrypt: Done!\n");
#endif

  for (i = 0;i < CRYPTO_ABYTES;++i) tag[i] = lenblock[i] ^ accum[i] ^ init[i];

  if (crypto_verify_16(tag,c) != 0) return -1;

  return 0;
}
