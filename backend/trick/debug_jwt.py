import sys
import json
from jose import jwt
from app.config.settings import get_settings

# Get settings
settings = get_settings()

def debug_token(token: str):
    """
    Debug a JWT token using your application's secret key
    """
    print("\n=== JWT Token Debugging ===")
    
    try:
        # Decode token with verification
        payload = jwt.decode(
            token, 
            settings.jwt.secret_key, 
            algorithms=[settings.jwt.algorithm]
        )
        
        print("\n✅ Token is VALID with current secret key!")
        print(f"\nToken payload:")
        print(json.dumps(payload, indent=2))
        
        # Additional token info
        if "exp" in payload:
            import datetime
            exp_time = datetime.datetime.fromtimestamp(payload["exp"])
            now = datetime.datetime.utcnow()
            time_until_exp = exp_time - now
            
            print(f"\nToken expires at: {exp_time}")
            print(f"Current UTC time:  {now}")
            
            if time_until_exp.total_seconds() > 0:
                print(f"Time until expiration: {time_until_exp}")
            else:
                print(f"Token EXPIRED {abs(time_until_exp)} ago!")
        
        # Check for session ID
        if "session_id" in payload:
            print(f"\nSession ID: {payload['session_id']}")
        else:
            print("\n⚠️ No session_id in token!")
            
    except Exception as e:
        print(f"\n❌ Error verifying token: {str(e)}")
        
        # Also show raw decoded content for debugging
        from base64 import urlsafe_b64decode
        
        try:
            # Split the token
            parts = token.split('.')
            if len(parts) == 3:
                header_b64, payload_b64, signature = parts
                
                # Add padding if needed
                def decode_base64_part(b64_str):
                    padding = 4 - (len(b64_str) % 4)
                    if padding < 4:
                        b64_str += '=' * padding
                    return urlsafe_b64decode(b64_str.encode()).decode()
                
                # Try to decode without verification
                print("\nRaw token content (not verified):")
                print(f"HEADER: {json.dumps(json.loads(decode_base64_part(header_b64)), indent=2)}")
                print(f"PAYLOAD: {json.dumps(json.loads(decode_base64_part(payload_b64)), indent=2)}")
            else:
                print("\n❌ Invalid token format")
        except Exception as inner_e:
            print(f"\n❌ Failed to decode token parts: {str(inner_e)}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        # Token from command line
        debug_token(sys.argv[1])
    else:
        # Prompt for token
        token = input("Enter JWT token to debug: ")
        debug_token(token)
