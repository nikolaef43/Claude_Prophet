#!/bin/bash

# Autonomous Trading Bot Launcher
# Starts the Go trading backend and runs autonomous trading session

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Prophet Autonomous Trading System${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if trading bot is already running
if lsof -Pi :4534 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Trading bot already running on port 4534${NC}"
else
    echo -e "${YELLOW}Starting Go trading bot...${NC}"

    # Load environment variables
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi

    # Start the trading bot in background
    ALPACA_API_KEY=${ALPACA_API_KEY:-$ALPACA_PUBLIC_KEY} \
    ALPACA_SECRET_KEY=${ALPACA_SECRET_KEY} \
    nohup go run ./cmd/bot/main.go > trading_bot.log 2>&1 &

    echo $! > trading_bot.pid

    # Wait for bot to start
    echo -e "${YELLOW}Waiting for trading bot to initialize...${NC}"
    sleep 5

    # Verify it's running
    if lsof -Pi :4534 -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Trading bot started successfully (PID: $(cat trading_bot.pid))${NC}"
    else
        echo -e "${RED}✗ Failed to start trading bot. Check trading_bot.log${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}System Ready for Autonomous Trading${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Portfolio Status:"
echo "  • Cash: $(curl -s http://localhost:4534/api/v1/account | grep -o '"Cash":[0-9.]*' | cut -d: -f2 || echo 'N/A')"
echo "  • Buying Power: $(curl -s http://localhost:4534/api/v1/account | grep -o '"BuyingPower":[0-9.]*' | cut -d: -f2 || echo 'N/A')"
echo ""
echo -e "${YELLOW}Starting Claude autonomous trading agent...${NC}"
echo ""

# Run Claude in headless mode with JSON output
LOG_FILE="autonomous_session_$(date +%Y%m%d_%H%M%S).log"

echo "Running autonomous session, logging to: $LOG_FILE"
echo ""

claude --print \
       --verbose \
       --output-format stream-json \
       --permission-mode acceptEdits \
       "$(cat autonomous_trading_prompt.txt)" \
       | tee "$LOG_FILE"

echo ""
echo -e "${GREEN}Autonomous session complete.${NC}"
echo ""
echo "Session log: $LOG_FILE"
echo "Trading bot log: tail -f trading_bot.log"
echo "Activity log: cat activity_logs/activity_$(date +%Y-%m-%d).json"
echo ""
echo "To stop trading bot: kill $(cat trading_bot.pid 2>/dev/null || echo 'N/A')"
