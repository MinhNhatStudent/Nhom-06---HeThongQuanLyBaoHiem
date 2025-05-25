import sys
import json
from base64 import b64decode
from typing import Dict, Any

def decode_jwt(token: str) -> Dict[str, Any]:
    """
    Decode a JWT token without verification
    
    This function is for debugging purposes only and should not be used in production
    as it doesn't verify the signature of the token.
    """
    # Split the token into its three parts
    if not token:
        return {"error": "No token provided"}
    
    try:
        header_b64, payload_b64, signature = token.split('.')
    except ValueError:
        return {"error": "Invalid JWT format"}
    
    # Decode the header and payload
    try:
        # Handle padding for base64
        def decode_base64(b64_str):
            # Add padding if needed
            padding = len(b64_str) % 4
            if padding:
                b64_str += '=' * (4 - padding)
            # Replace URL-safe characters
            b64_str = b64_str.replace('-', '+').replace('_', '/')
            # Decode
            return b64decode(b64_str)
        
        header_json = decode_base64(header_b64)
        payload_json = decode_base64(payload_b64)
        
        header = json.loads(header_json)
        payload = json.loads(payload_json)
        
        return {
            "header": header,
            "payload": payload,
            "signature": signature[:10] + "..." # Just show part of the signature
        }
    except Exception as e:
        return {"error": f"Error decoding token: {str(e)}"}

def main():
    """Main function to run when script is executed directly"""
    if len(sys.argv) > 1:
        token = sys.argv[1]
        result = decode_jwt(token)
        print(json.dumps(result, indent=2))
    else:
        print("Please provide a JWT token as a command line argument")
        token = input("Or paste your JWT token here: ")
        if token:
            result = decode_jwt(token)
            print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
