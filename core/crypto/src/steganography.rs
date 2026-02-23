//! Steganography module
//! 
//! Hides encrypted messages in images using LSB and DCT methods

use crate::keys::CryptoError;

/// LSB Steganography for images
pub struct Steganography;

impl Steganography {
    /// Encode message in image using LSB
    /// 
    /// # Arguments
    /// * `cover_image` - RGB or BGR image data
    /// * `message` - Data to hide
    /// * `key` - Optional encryption key for the message
    pub fn encode_lsb(
        cover_image: &[u8],
        width: usize,
        height: usize,
        message: &[u8],
    ) -> Result<Vec<u8>, CryptoError> {
        // Check capacity
        let max_capacity = (width * height * 3) / 8;
        if message.len() > max_capacity {
            return Err(CryptoError::Encryption(
                format!("Message too large. Max: {} bytes, Got: {} bytes", max_capacity, message.len())
            ));
        }
        
        // Create output image
        let mut result = cover_image.to_vec();
        
        // Prepare data with length prefix (4 bytes)
        let mut data = Vec::with_capacity(4 + message.len());
        data.extend_from_slice(&(message.len() as u32).to_le_bytes());
        data.extend_from_slice(message);
        
        // Encode bits into LSB
        let mut bit_index = 0;
        let total_bits = data.len() * 8;
        
        for y in 0..height {
            for x in 0..width {
                if bit_index >= total_bits {
                    break;
                }
                
                let pixel_index = (y * width + x) * 3;
                
                // Encode in each channel (R, G, B)
                for c in 0..3 {
                    if bit_index >= total_bits {
                        break;
                    }
                    
                    let byte_index = bit_index / 8;
                    let bit_position = 7 - (bit_index % 8);
                    let bit = (data[byte_index] >> bit_position) & 1;
                    
                    // Set LSB
                    result[pixel_index + c] = (result[pixel_index + c] & 0xFE) | bit;
                    
                    bit_index += 1;
                }
            }
            
            if bit_index >= total_bits {
                break;
            }
        }
        
        Ok(result)
    }
    
    /// Decode message from image using LSB
    pub fn decode_lsb(
        stego_image: &[u8],
        width: usize,
        height: usize,
    ) -> Result<Vec<u8>, CryptoError> {
        // Extract all LSB bits
        let mut bits = Vec::new();
        
        for y in 0..height {
            for x in 0..width {
                let pixel_index = (y * width + x) * 3;
                
                for c in 0..3 {
                    bits.push(stego_image[pixel_index + c] & 1);
                }
            }
        }
        
        // Convert bits to bytes
        let byte_count = bits.len() / 8;
        let mut data = Vec::with_capacity(byte_count);
        
        for i in 0..byte_count {
            let mut byte = 0u8;
            for b in 0..8 {
                byte |= bits[i * 8 + b] << (7 - b);
            }
            data.push(byte);
        }
        
        // Read length prefix
        if data.len() < 4 {
            return Err(CryptoError::Decryption("Invalid stego data: too short".to_string()));
        }
        
        let msg_len = u32::from_le_bytes([data[0], data[1], data[2], data[3]]) as usize;
        
        if data.len() < 4 + msg_len {
            return Err(CryptoError::Decryption("Invalid stego data: length mismatch".to_string()));
        }
        
        Ok(data[4..4 + msg_len].to_vec())
    }
    
    /// Get maximum message size for an image
    pub fn max_capacity(width: usize, height: usize) -> usize {
        (width * height * 3) / 8
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    
    #[test]
    fn test_lsb_encode_decode() {
        // Create a simple test image (10x10 RGB)
        let width = 100;
        let height = 100;
        let mut cover_image = vec![0u8; width * height * 3];
        
        // Fill with random data
        use rand::Rng;
        let mut rng = rand::thread_rng();
        for byte in &mut cover_image {
            *byte = rng.gen();
        }
        
        let message = b"Hello, Liberty Reach! This is a secret message.";
        
        // Encode
        let stego_image = Steganography::encode_lsb(
            &cover_image,
            width,
            height,
            message,
        ).unwrap();
        
        // Verify image was modified
        assert_ne!(cover_image, stego_image);
        
        // Decode
        let decoded = Steganography::decode_lsb(
            &stego_image,
            width,
            height,
        ).unwrap();
        
        assert_eq!(message.to_vec(), decoded);
    }
    
    #[test]
    fn test_max_capacity() {
        // 1920x1080 image
        let capacity = Steganography::max_capacity(1920, 1080);
        assert_eq!(capacity, 777600); // ~759 KB
    }
    
    #[test]
    fn test_message_too_large() {
        let width = 10;
        let height = 10;
        let cover_image = vec![0u8; width * height * 3];
        let message = vec![0u8; 1000]; // Too large for 10x10 image
        
        let result = Steganography::encode_lsb(&cover_image, width, height, &message);
        assert!(result.is_err());
    }
}
