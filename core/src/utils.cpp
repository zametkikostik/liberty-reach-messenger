/**
 * Utility functions implementation
 */

#include "liberty_reach_crypto.h"
#include <sstream>
#include <iomanip>

namespace td {
namespace liberty_reach {

std::string hex_encode(const ByteArray& data) {
  std::ostringstream oss;
  for (auto byte : data) {
    oss << std::hex << std::setw(2) << std::setfill('0') 
        << static_cast<int>(byte);
  }
  return oss.str();
}

ByteArray hex_decode(std::string_view hex) {
  ByteArray bytes;
  bytes.reserve(hex.size() / 2);
  
  for (std::size_t i = 0; i < hex.size(); i += 2) {
    std::uint8_t byte = static_cast<std::uint8_t>(
        std::stoi(std::string(hex.substr(i, 2)), nullptr, 16));
    bytes.push_back(byte);
  }
  
  return bytes;
}

}  // namespace liberty_reach
}  // namespace td
