import requests
import sys
import json
import time
from base64 import urlsafe_b64decode

# Base URL of your API - change if needed
BASE_URL = "http://localhost:8000"

# ANSI color codes for better readability
GREEN = "\033[92m"
RED = "\033[91m"
BLUE = "\033[94m"
YELLOW = "\033[93m"
RESET = "\033[0m"

def print_with_color(message, color=BLUE):
    print(f"{color}{message}{RESET}")

def decode_token_parts(token):
    """Decode token parts without verification for debugging"""
    try:
        # Split the token
        parts = token.split('.')
        if len(parts) != 3:
            return {"error": "Invalid token format"}

        header_b64, payload_b64, signature = parts
        
        # Add padding if needed
        def decode_base64_part(b64_str):
            padding = 4 - (len(b64_str) % 4)
            if padding < 4:
                b64_str += '=' * padding
            return urlsafe_b64decode(b64_str.replace("-", "+").replace("_", "/").encode()).decode()
        
        # Decode parts
        header = json.loads(decode_base64_part(header_b64))
        payload = json.loads(decode_base64_part(payload_b64))
        
        return {
            "header": header,
            "payload": payload,
            "signature_prefix": signature[:10]
        }
    except Exception as e:
        return {"error": f"Failed to decode token: {str(e)}"}

def test_auth_debug():
    print_with_color("\n=== Enhanced Authentication Debugging ===", BLUE)
    
    # Step 1: Login to get token
    print_with_color("\n1. Logging in...", BLUE)
    login_url = f"{BASE_URL}/auth/login"
    
    # Get username and password from user
    username = input("Enter your username/email: ")
    password = input("Enter your password: ")
    
    login_data = {
        "username": username,
        "password": password
    }
    
    try:
        login_response = requests.post(
            login_url,
            data=login_data,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        if login_response.status_code == 200:
            token_data = login_response.json()
            access_token = token_data.get("access_token")
            token_type = token_data.get("token_type")
            expires_at = token_data.get("expires_at")
            
            print_with_color(f"Login successful!", GREEN)
            print_with_color(f"Token Type: {token_type}")
            print_with_color(f"Expires At: {expires_at}")
            
            # Decode token parts without verification for debugging
            print_with_color("\nDecoding token for inspection:", YELLOW)
            token_parts = decode_token_parts(access_token)
            
            if "error" not in token_parts:
                print_with_color("Token Header:", YELLOW)
                print(json.dumps(token_parts["header"], indent=2))
                
                print_with_color("\nToken Payload:", YELLOW)
                print(json.dumps(token_parts["payload"], indent=2))
                
                # Check for required fields
                payload = token_parts["payload"]
                session_id = payload.get("session_id")
                sub = payload.get("sub")
                role = payload.get("vai_tro")
                exp = payload.get("exp")
                
                if not session_id:
                    print_with_color("⚠️ Token missing session_id field!", RED)
                if not sub:
                    print_with_color("⚠️ Token missing sub field!", RED)
                if not role:
                    print_with_color("⚠️ Token missing vai_tro field!", RED)
                if not exp:
                    print_with_color("⚠️ Token missing exp field!", RED)
                elif exp < time.time():
                    print_with_color("⚠️ Token is expired!", RED)
            else:
                print_with_color(f"⚠️ {token_parts['error']}", RED)
            
            # Step 2: Test custom auth header
            print_with_color("\n2. Testing various Authorization header formats...", BLUE)
            validate_url = f"{BASE_URL}/auth/validate"
            
            headers_to_test = [
                {"Authorization": f"Bearer {access_token}"},
                {"Authorization": f"bearer {access_token}"},
                {"Authorization": f"{token_type} {access_token}"},
                {"Authorization": access_token}
            ]
            
            for i, headers in enumerate(headers_to_test):
                print_with_color(f"\nTesting header format {i+1}: {headers['Authorization'][:15]}...", YELLOW)
                
                try:
                    response = requests.get(validate_url, headers=headers)
                    
                    if response.status_code == 200:
                        print_with_color(f"✅ Success with header format {i+1}!", GREEN)
                        print_with_color(f"Response: {json.dumps(response.json(), indent=2)}")
                        
                        # Use this successful format for logout test
                        print_with_color("\n3. Testing logout with working header format...", BLUE)
                        logout_url = f"{BASE_URL}/auth/logout"
                        
                        logout_response = requests.post(logout_url, headers=headers)
                        
                        if logout_response.status_code == 200:
                            print_with_color("✅ Logout successful!", GREEN)
                            print_with_color(f"Response: {json.dumps(logout_response.json(), indent=2)}")
                        else:
                            print_with_color(f"❌ Logout failed with status code: {logout_response.status_code}", RED)
                            print_with_color(f"Response: {logout_response.text}")
                        
                        # Break after finding a working format
                        break
                    else:
                        print_with_color(f"❌ Failed with status code: {response.status_code}", RED)
                        print_with_color(f"Response: {response.text}")
                        
                except Exception as e:
                    print_with_color(f"❌ Error: {str(e)}", RED)
            
            # Step 4: Test direct endpoint
            print_with_color("\n4. Testing non-authenticated endpoint for comparison...", BLUE)
            test_url = f"{BASE_URL}/auth/test"
            
            try:
                test_response = requests.get(test_url)
                
                if test_response.status_code == 200:
                    print_with_color("✅ Non-authenticated endpoint works!", GREEN)
                    print_with_color(f"Response: {json.dumps(test_response.json(), indent=2)}")
                else:
                    print_with_color(f"❌ Non-authenticated endpoint failed: {test_response.status_code}", RED)
                    print_with_color(f"Response: {test_response.text}")
            except Exception as e:
                print_with_color(f"❌ Error: {str(e)}", RED)
                
        else:
            print_with_color(f"❌ Login failed with status code: {login_response.status_code}", RED)
            print_with_color(f"Response: {login_response.text}")
            
    except Exception as e:
        print_with_color(f"❌ Error during authentication test: {str(e)}", RED)
    
    print_with_color("\n=== Debug Information for Support ===", BLUE)
    print("If the issue persists, provide the following details to support:")
    print("1. Your API URL")
    print("2. The decoded token information (excluding signature)")
    print("3. The exact error messages received")

if __name__ == "__main__":
    test_auth_debug()
