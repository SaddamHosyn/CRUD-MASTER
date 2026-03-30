#!/bin/bash

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║          CRUD MASTER - LOCAL TESTING SCRIPT (V2)              ║"
echo "║                    March 30, 2026                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Function to test endpoint
test_endpoint() {
    local METHOD=$1
    local URL=$2
    local DATA=$3
    local EXPECTED_CODE=$4
    local DESCRIPTION=$5
    
    echo ""
    echo "🧪 Testing: $DESCRIPTION"
    echo "   Method: $METHOD | URL: $URL"
    
    if [ -z "$DATA" ]; then
        RESPONSE=$(curl -s -w "\n%{http_code}" -X $METHOD "$URL" -H "Content-Type: application/json")
    else
        RESPONSE=$(curl -s -w "\n%{http_code}" -X $METHOD "$URL" -H "Content-Type: application/json" -d "$DATA")
    fi
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | head -n -1)
    
    if [ "$HTTP_CODE" = "$EXPECTED_CODE" ] || [ "$HTTP_CODE" = "20" ]; then
        echo -e "   ${GREEN}✅ PASS${NC} (HTTP $HTTP_CODE)"
        echo "   Response: $(echo $BODY | head -c 80)..."
        TESTS_PASSED=$((TESTS_PASSED + 1))
        
        # Extract and save movie ID if this was a create
        if [[ "$DESCRIPTION" == *"Create Movie"* ]]; then
            MOVIE_ID=$(echo "$BODY" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('movie', {}).get('id', ''))" 2>/dev/null)
            if [ ! -z "$MOVIE_ID" ]; then
                echo "   📝 Saved Movie ID: $MOVIE_ID"
                echo "$MOVIE_ID" > /tmp/movie_id.txt
            fi
        fi
    else
        echo -e "   ${RED}❌ FAIL${NC} (Expected $EXPECTED_CODE, got $HTTP_CODE)"
        echo "   Response: $BODY"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Test infrastructure
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Infrastructure Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check RabbitMQ
docker ps | grep -q rabbitmq && echo -e "${GREEN}✅ RabbitMQ${NC} - Running" || echo -e "${RED}❌ RabbitMQ${NC} - Not found"

# Check PostgreSQL
psql -U postgres -d movies -c "SELECT 1" >/dev/null 2>&1 && echo -e "${GREEN}✅ PostgreSQL${NC} - Accessible" || echo -e "${RED}❌ PostgreSQL${NC} - Not accessible"

# Check services running
lsof -i :3000 >/dev/null 2>&1 && echo -e "${GREEN}✅ API Gateway${NC} - Port 3000" || echo -e "${RED}❌ API Gateway${NC} - Port 3000"
lsof -i :8080 >/dev/null 2>&1 && echo -e "${GREEN}✅ Inventory API${NC} - Port 8080" || echo -e "${RED}❌ Inventory API${NC} - Port 8080"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Endpoint Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test 1: Health Check
test_endpoint "GET" "http://localhost:3000/health" "" "200" "Health Check"

# Test 2: Create Movie
MOVIE_DATA='{"title":"Inception","description":"A mind-bending thriller","genre":"Sci-Fi","release_year":2010,"rating":8.8,"duration":148,"available_copies":5}'
test_endpoint "POST" "http://localhost:3000/api/movies" "$MOVIE_DATA" "201" "Create Movie"

# Get Movie ID for next tests
MOVIE_ID=$(cat /tmp/movie_id.txt 2>/dev/null || echo "1")

# Test 3: Get All Movies
test_endpoint "GET" "http://localhost:3000/api/movies" "" "200" "Get All Movies"

# Test 4: Get Movie by ID
test_endpoint "GET" "http://localhost:3000/api/movies/$MOVIE_ID" "" "200" "Get Movie by ID"

# Test 5: Update Movie
UPDATE_DATA='{"rating":9.0,"available_copies":3}'
test_endpoint "PUT" "http://localhost:3000/api/movies/$MOVIE_ID" "$UPDATE_DATA" "200" "Update Movie"

# Test 6: Create Order (RabbitMQ)
ORDER_DATA='{"user_id":"user123","number_of_items":"5","total_amount":"49.99"}'
test_endpoint "POST" "http://localhost:3000/api/billing" "$ORDER_DATA" "200" "Create Order (RabbitMQ)"

# Test 7: Delete Movie
test_endpoint "DELETE" "http://localhost:3000/api/movies/$MOVIE_ID" "" "200" "Delete Movie"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Results Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Passed: $TESTS_PASSED${NC}"
echo -e "${RED}❌ Failed: $TESTS_FAILED${NC}"
TOTAL=$((TESTS_PASSED + TESTS_FAILED))
PERCENTAGE=$((TESTS_PASSED * 100 / TOTAL))
echo "Total: $TOTAL tests | Pass Rate: $PERCENTAGE%"
echo ""

# Check database
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Database Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Movies in database:"
psql -U inventory_user -d movies -c "SELECT id, title, genre, release_year FROM movie LIMIT 5;" 2>/dev/null || echo "❌ Cannot query movies table"

echo ""
echo "Orders in database:"
psql -U billing_user -d orders -c "SELECT * FROM orders LIMIT 5;" 2>/dev/null || echo "❌ Cannot query orders table"

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
if [ $TESTS_FAILED -eq 0 ]; then
    echo "║              🎉 ALL TESTS PASSED! 🎉                       ║"
else
    echo "║           ⚠️  Some tests failed - Review above ⚠️            ║"
fi
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
