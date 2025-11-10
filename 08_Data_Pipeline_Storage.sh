#!/bin/bash

# Create the files and thier content for Applications manifests

cat > ~/trading-ai-system/applications/data-pipeline/schema/001_initial_schema.sql << 'EOF'
-- ============================================
-- Trading AI System - Database Schema
-- Phase 2: Data Pipeline
-- ============================================


-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ============================================
-- Table: backtests
-- Stores backtest metadata and summary results
-- ============================================
CREATE TABLE IF NOT EXISTS backtests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Time range
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP NOT NULL,
    
    -- Financial metrics
    initial_balance DECIMAL(18, 2) NOT NULL,
    final_balance DECIMAL(18, 2),
    net_profit DECIMAL(18, 2),
    gross_profit DECIMAL(18, 2),
    gross_loss DECIMAL(18, 2),
    
    -- Trade statistics
    total_trades INTEGER DEFAULT 0,
    winning_trades INTEGER DEFAULT 0,
    losing_trades INTEGER DEFAULT 0,
    win_rate DECIMAL(5, 2),
    
    -- Performance metrics
    profit_factor DECIMAL(10, 4),
    sharpe_ratio DECIMAL(10, 4),
    sortino_ratio DECIMAL(10, 4),
    max_drawdown DECIMAL(10, 4),
    max_drawdown_percent DECIMAL(10, 4),
    recovery_factor DECIMAL(10, 4),
    
    -- Trade metrics
    avg_trade_profit DECIMAL(18, 2),
    avg_winning_trade DECIMAL(18, 2),
    avg_losing_trade DECIMAL(18, 2),
    largest_winning_trade DECIMAL(18, 2),
    largest_losing_trade DECIMAL(18, 2),
    avg_trade_duration_seconds INTEGER,
    
    -- Risk metrics
    max_consecutive_wins INTEGER,
    max_consecutive_losses INTEGER,
    avg_risk_reward_ratio DECIMAL(10, 4),
    
    -- Metadata
    parameters JSONB,
    raw_file_path TEXT,
    status VARCHAR(50) DEFAULT 'pending', -- pending, processing, completed, failed
    error_message TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP
);


-- Indexes for backtests
CREATE INDEX idx_backtests_created_at ON backtests(created_at DESC);
CREATE INDEX idx_backtests_status ON backtests(status);
CREATE INDEX idx_backtests_date_range ON backtests(start_date, end_date);
CREATE INDEX idx_backtests_name ON backtests(name);


-- ============================================
-- Table: trades
-- Stores individual trade records
-- ============================================
CREATE TABLE IF NOT EXISTS trades (
    id BIGSERIAL PRIMARY KEY,
    backtest_id UUID NOT NULL REFERENCES backtests(id) ON DELETE CASCADE,
    
    -- Trade identification
    trade_id VARCHAR(100),
    position_id VARCHAR(100),
    
    -- Timing
    open_time TIMESTAMP NOT NULL,
    close_time TIMESTAMP,
    duration_seconds INTEGER,
    
    -- Instrument
    symbol VARCHAR(20) NOT NULL,
    
    -- Trade details
    direction VARCHAR(10) NOT NULL, -- BUY, SELL
    entry_price DECIMAL(18, 8) NOT NULL,
    exit_price DECIMAL(18, 8),
    volume DECIMAL(18, 8) NOT NULL,
    
    -- Results
    profit DECIMAL(18, 8),
    profit_percent DECIMAL(10, 4),
    pips DECIMAL(10, 2),
    commission DECIMAL(18, 8),
    swap DECIMAL(18, 8),
    
    -- Stop loss & Take profit
    stop_loss DECIMAL(18, 8),
    take_profit DECIMAL(18, 8),
    
    -- Running metrics
    balance_after DECIMAL(18, 2),
    equity_after DECIMAL(18, 2),
    drawdown DECIMAL(18, 2),
    drawdown_percent DECIMAL(10, 4),
    
    -- Additional data
    metadata JSONB,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW()
);


-- Indexes for trades
CREATE INDEX idx_trades_backtest_id ON trades(backtest_id);
CREATE INDEX idx_trades_open_time ON trades(open_time);
CREATE INDEX idx_trades_close_time ON trades(close_time);
CREATE INDEX idx_trades_symbol ON trades(symbol);
CREATE INDEX idx_trades_direction ON trades(direction);
CREATE INDEX idx_trades_profit ON trades(profit);


-- Composite indexes for common queries
CREATE INDEX idx_trades_backtest_time ON trades(backtest_id, open_time);
CREATE INDEX idx_trades_backtest_symbol ON trades(backtest_id, symbol);


-- ============================================
-- Table: parameters
-- Stores bot parameters for each backtest
-- ============================================
CREATE TABLE IF NOT EXISTS parameters (
    id SERIAL PRIMARY KEY,
    backtest_id UUID NOT NULL REFERENCES backtests(id) ON DELETE CASCADE,
    
    parameter_name VARCHAR(100) NOT NULL,
    parameter_value TEXT,
    parameter_type VARCHAR(50), -- string, integer, float, boolean
    parameter_group VARCHAR(100), -- e.g., 'indicators', 'risk_management'
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(backtest_id, parameter_name)
);


-- Indexes for parameters
CREATE INDEX idx_parameters_backtest_id ON parameters(backtest_id);
CREATE INDEX idx_parameters_name ON parameters(parameter_name);


-- ============================================
-- Table: daily_summary
-- Aggregated daily performance
-- ============================================
CREATE TABLE IF NOT EXISTS daily_summary (
    id SERIAL PRIMARY KEY,
    backtest_id UUID NOT NULL REFERENCES backtests(id) ON DELETE CASCADE,
    
    trade_date DATE NOT NULL,
    
    -- Daily statistics
    total_trades INTEGER DEFAULT 0,
    winning_trades INTEGER DEFAULT 0,
    losing_trades INTEGER DEFAULT 0,
    
    -- Daily P&L
    gross_profit DECIMAL(18, 2),
    gross_loss DECIMAL(18, 2),
    net_profit DECIMAL(18, 2),
    
    -- Daily metrics
    win_rate DECIMAL(5, 2),
    avg_profit DECIMAL(18, 2),
    max_profit DECIMAL(18, 2),
    max_loss DECIMAL(18, 2),
    
    -- Balance tracking
    starting_balance DECIMAL(18, 2),
    ending_balance DECIMAL(18, 2),
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(backtest_id, trade_date)
);


-- Indexes for daily_summary
CREATE INDEX idx_daily_summary_backtest_id ON daily_summary(backtest_id);
CREATE INDEX idx_daily_summary_date ON daily_summary(trade_date);


-- ============================================
-- Table: ingestion_jobs
-- Tracks data ingestion jobs
-- ============================================
CREATE TABLE IF NOT EXISTS ingestion_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    backtest_id UUID REFERENCES backtests(id),
    
    job_type VARCHAR(50) NOT NULL, -- 'json_parse', 'csv_parse', 'validation'
    status VARCHAR(50) DEFAULT 'pending', -- pending, running, completed, failed
    
    -- File information
    file_name VARCHAR(255),
    file_size_bytes BIGINT,
    file_path TEXT,
    
    -- Processing metrics
    records_total INTEGER,
    records_processed INTEGER,
    records_failed INTEGER,
    
    -- Timing
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    duration_seconds INTEGER,
    
    -- Error handling
    error_message TEXT,
    error_details JSONB,
    
    created_at TIMESTAMP DEFAULT NOW()
);


-- Indexes for ingestion_jobs
CREATE INDEX idx_ingestion_jobs_status ON ingestion_jobs(status);
CREATE INDEX idx_ingestion_jobs_backtest_id ON ingestion_jobs(backtest_id);
CREATE INDEX idx_ingestion_jobs_created_at ON ingestion_jobs(created_at DESC);


-- ============================================
-- Functions and Triggers
-- ============================================


-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Trigger for backtests table
CREATE TRIGGER update_backtests_updated_at
    BEFORE UPDATE ON backtests
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- Function to calculate backtest summary
CREATE OR REPLACE FUNCTION calculate_backtest_summary(p_backtest_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE backtests SET
        total_trades = (SELECT COUNT(*) FROM trades WHERE backtest_id = p_backtest_id),
        winning_trades = (SELECT COUNT(*) FROM trades WHERE backtest_id = p_backtest_id AND profit > 0),
        losing_trades = (SELECT COUNT(*) FROM trades WHERE backtest_id = p_backtest_id AND profit < 0),
        net_profit = (SELECT SUM(profit) FROM trades WHERE backtest_id = p_backtest_id),
        gross_profit = (SELECT SUM(profit) FROM trades WHERE backtest_id = p_backtest_id AND profit > 0),
        gross_loss = (SELECT ABS(SUM(profit)) FROM trades WHERE backtest_id = p_backtest_id AND profit < 0),
        avg_trade_profit = (SELECT AVG(profit) FROM trades WHERE backtest_id = p_backtest_id),
        avg_winning_trade = (SELECT AVG(profit) FROM trades WHERE backtest_id = p_backtest_id AND profit > 0),
        avg_losing_trade = (SELECT AVG(profit) FROM trades WHERE backtest_id = p_backtest_id AND profit < 0),
        largest_winning_trade = (SELECT MAX(profit) FROM trades WHERE backtest_id = p_backtest_id),
        largest_losing_trade = (SELECT MIN(profit) FROM trades WHERE backtest_id = p_backtest_id),
        avg_trade_duration_seconds = (SELECT AVG(duration_seconds) FROM trades WHERE backtest_id = p_backtest_id)
    WHERE id = p_backtest_id;
    
    -- Calculate win rate
    UPDATE backtests SET
        win_rate = CASE 
            WHEN total_trades > 0 THEN (winning_trades::DECIMAL / total_trades * 100)
            ELSE 0
        END,
        profit_factor = CASE
            WHEN gross_loss > 0 THEN (gross_profit / gross_loss)
            ELSE NULL
        END
    WHERE id = p_backtest_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- Sample Queries (for reference)
-- ============================================


-- Get backtest summary
-- SELECT * FROM backtests WHERE id = 'your-uuid';


-- Get all trades for a backtest
-- SELECT * FROM trades WHERE backtest_id = 'your-uuid' ORDER BY open_time;


-- Get daily performance
-- SELECT * FROM daily_summary WHERE backtest_id = 'your-uuid' ORDER BY trade_date;


-- Get winning trades only
-- SELECT * FROM trades WHERE backtest_id = 'your-uuid' AND profit > 0;


-- Get trades by symbol
-- SELECT symbol, COUNT(*), SUM(profit) as total_profit
-- FROM trades WHERE backtest_id = 'your-uuid'
-- GROUP BY symbol ORDER BY total_

-- Get trades by symbol
-- SELECT symbol, COUNT(*), SUM(profit) as total_profit
-- FROM trades WHERE backtest_id = 'your-uuid'
-- GROUP BY symbol ORDER BY total_profit DESC;


-- Get parameters for a backtest
-- SELECT * FROM parameters WHERE backtest_id = 'your-uuid';


-- ============================================
-- Grants (adjust username as needed)
-- ============================================
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO trading_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO trading_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO trading_user;

EOF

cat > ~/trading-ai-system/applications/data-pipeline/requirements.txt << 'EOF'
# Core dependencies
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
pydantic-settings==2.1.0


# Database
psycopg2-binary==2.9.9
sqlalchemy==2.0.23
alembic==1.12.1


# Data processing
pandas==2.1.3
polars==0.19.12
numpy==1.26.2


# Validation
jsonschema==4.20.0


# Utilities
python-multipart==0.0.6
python-dotenv==1.0.0
aiofiles==23.2.1


# Testing
pytest==7.4.3
pytest-asyncio==0.21.1
httpx==0.25.2

EOF

cat > ~/trading-ai-system/applications/data-pipeline/src/config.py << 'EOF'
"""
Configuration management for data pipeline
"""
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    """Application settings"""
    
    # Application
    APP_NAME: str = "Trading AI Data Pipeline"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False
    
    # Database
    DATABASE_URL: str = "postgresql://trading_user:TradingAI2025!@postgres.databases.svc.cluster.local:5432/trading_db"
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 40
    
    # File storage
    RAW_DATA_PATH: str = "/mnt/trading-data/raw"
    PROCESSED_DATA_PATH: str = "/mnt/trading-data/processed"
    
    # Processing limits
    MAX_FILE_SIZE_MB: int = 500
    BATCH_SIZE: int = 10000
    
    # API
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    
    class Config:
        env_file = ".env"
        case_sensitive = True




settings = Settings()

EOF

cat > ~/trading-ai-system/applications/data-pipeline/src/models/database.py << 'EOF'
"""
SQLAlchemy database models
"""
from sqlalchemy import create_engine, Column, String, Integer, BigInteger, DECIMAL, TIMESTAMP, Text, Boolean
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import uuid


from ..config import settings


# Create engine
engine = create_engine(
    settings.DATABASE_URL,
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    pool_pre_ping=True
)


# Create session
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class
Base = declarative_base()

class Backtest(Base):
    """Backtest model"""
    __tablename__ = "backtests"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String(255), nullable=False)
    description = Column(Text)
    
    start_date = Column(TIMESTAMP, nullable=False)
    end_date = Column(TIMESTAMP, nullable=False)
    
    initial_balance = Column(DECIMAL(18, 2), nullable=False)
    final_balance = Column(DECIMAL(18, 2))
    net_profit = Column(DECIMAL(18, 2))
    
    total_trades = Column(Integer, default=0)
    winning_trades = Column(Integer, default=0)
    losing_trades = Column(Integer, default=0)
    win_rate = Column(DECIMAL(5, 2))
    
    profit_factor = Column(DECIMAL(10, 4))
    sharpe_ratio = Column(DECIMAL(10, 4))
    max_drawdown = Column(DECIMAL(10, 4))
    
    parameters = Column(JSONB)
    raw_file_path = Column(Text)
    status = Column(String(50), default='pending')
    error_message = Column(Text)
    
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow)
    processed_at = Column(TIMESTAMP)

class Trade(Base):
    """Trade model"""
    __tablename__ = "trades"
    
    id = Column(BigInteger, primary_key=True)
    backtest_id = Column(UUID(as_uuid=True), nullable=False)
    
    trade_id = Column(String(100))
    position_id = Column(String(100))
    
    open_time = Column(TIMESTAMP, nullable=False)
    close_time = Column(TIMESTAMP)
    duration_seconds = Column(Integer)
    
    symbol = Column(String(20), nullable=False)
    direction = Column(String(10), nullable=False)
    
    entry_price = Column(DECIMAL(18, 8), nullable=False)
    exit_price = Column(DECIMAL(18, 8))
    volume = Column(DECIMAL(18, 8), nullable=False)
    
    profit = Column(DECIMAL(18, 8))
    pips = Column(DECIMAL(10, 2))
    
    stop_loss = Column(DECIMAL(18, 8))
    take_profit = Column(DECIMAL(18, 8))
    
    balance_after = Column(DECIMAL(18, 2))
    drawdown = Column(DECIMAL(18, 2))
    
    metadata = Column(JSONB)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)




class Parameter(Base):
    """Parameter model"""
    __tablename__ = "parameters"
    
    id = Column(Integer, primary_key=True)
    backtest_id = Column(UUID(as_uuid=True), nullable=False)
    
    parameter_name = Column(String(100), nullable=False)
    parameter_value = Column(Text)
    parameter_type = Column(String(50))
    parameter_group = Column(String(100))
    
    created_at = Column(TIMESTAMP, default=datetime.utcnow)




class IngestionJob(Base):
    """Ingestion job model"""
    __tablename__ = "ingestion_jobs"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    backtest_id = Column(UUID(as_uuid=True))
    
    job_type = Column(String(50), nullable=False)
    status = Column(String(50), default='pending')
    
    file_name = Column(String(255))
    file_size_bytes = Column(BigInteger)
    file_path = Column(Text)
    
    records_total = Column(Integer)
    records_processed = Column(Integer)
    records_failed = Column(Integer)
    
    started_at = Column(TIMESTAMP)
    completed_at = Column(TIMESTAMP)
    duration_seconds = Column(Integer)
    
    error_message = Column(Text)
    error_details = Column(JSONB)
    
    created_at = Column(TIMESTAMP, default=datetime.utcnow)




# Database dependency
def get_db():
    """Get database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

EOF

cat > ~/trading-ai-system/applications/data-pipeline/src/models/schemas.py << 'EOF'
"""
Pydantic schemas for request/response validation
"""
from pydantic import BaseModel, Field, validator
from typing import Optional, Dict, Any, List
from datetime import datetime
from uuid import UUID
from decimal import Decimal




class BacktestCreate(BaseModel):
    """Schema for creating a backtest"""
    name: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    initial_balance: Decimal = Field(..., gt=0)
    
    class Config:
        json_schema_extra = {
            "example": {
                "name": "EMA Crossover Strategy 2024",
                "description": "10-year backtest with EMA 20/50 crossover",
                "initial_balance": 10000.00
            }
        }




class BacktestResponse(BaseModel):
    """Schema for backtest response"""
    id: UUID
    name: str
    description: Optional[str]
    start_date: Optional[datetime]
    end_date: Optional[datetime]
    initial_balance: Decimal
    final_balance: Optional[Decimal]
    net_profit: Optional[Decimal]
    total_trades: int
    winning_trades: int
    losing_trades: int
    win_rate: Optional[Decimal]
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True




class TradeCreate(BaseModel):
    """Schema for creating a trade"""
    backtest_id: UUID
    open_time: datetime
    close_time: Optional[datetime]
    symbol: str
    direction: str
    entry_price: Decimal
    exit_price: Optional[Decimal]
    volume: Decimal
    profit: Optional[Decimal]
    
    @validator('direction')
    def validate_direction(cls, v):
        if v not in ['BUY', 'SELL']:
            raise ValueError('Direction must be BUY or SELL')
        return v




class IngestionRequest(BaseModel):
    """Schema for data ingestion request"""
    name: str
    description: Optional[str] = None
    initial_balance: Decimal = Field(default=10000.00, gt=0)
    
    class Config:
        json_schema_extra = {
            "example": {
                "name": "10yr_backtest_v1",
                "description": "Full 10-year backtest",
                "initial_balance": 10000.00
            }
        }




class IngestionResponse(BaseModel):
    """Schema for ingestion response"""
    job_id: UUID
    backtest_id: UUID
    status: str
    message: str
    
    class Config:
        json_schema_extra = {
            "example": {
                "job_id": "123e4567-e89b-12d3-a456-426614174000",
                "backtest_id": "123e4567-e89b-12d3-a456-426614174001",
                "status": "processing",
                "message": "Data ingestion started"
            }
        }




class JobStatus(BaseModel):
    """Schema for job status"""
    id: UUID
    status: str
    job_type: str
    records_total: Optional[int]
    records_processed: Optional[int]
    records_failed: Optional[int]
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    error_message: Optional[str]
    
    class Config:
        from_attributes = True

EOF

cat > ~/trading-ai-system/applications/data-pipeline/src/parsers/json_parser.py << 'EOF'
"""
JSON parser for cTrader backtest results
"""
import json
import pandas as pd
from typing import Dict, List, Any
from pathlib import Path
import logging


logger = logging.getLogger(__name__)




class CTraderJSONParser:
    """Parser for cTrader JSON exports"""
    
    def __init__(self, file_path: str):
        self.file_path = Path(file_path)
        self.data = None
        
    def parse(self) -> Dict[str, Any]:
        """Parse JSON file and extract data"""
        logger.info(f"Parsing JSON file: {self.file_path}")
        
        try:
            with open(self.file_path, 'r', encoding='utf-8') as f:
                self.data = json.load(f)
            
            logger.info(f"Successfully loaded JSON file")
            
            # Extract components
            result = {
                'backtest_info': self._extract_backtest_info(),
                'trades': self._extract_trades(),
                'parameters': self._extract_parameters(),
                'summary': self._extract_summary()
            }
            
            logger.info(f"Extracted {len(result['trades'])} trades")
            return result
            
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON format: {e}")
            raise ValueError(f"Invalid JSON file: {e}")
        except Exception as e:
            logger.error(f"Error parsing JSON: {e}")
            raise
    
    def _extract_backtest_info(self) -> Dict[str, Any]:
        """Extract backtest metadata"""
        return {
            'start_date': self.data.get('StartDate'),
            'end_date': self.data.get('EndDate'),
            'initial_balance': self.data.get('InitialBalance', 10000.00),
            'symbol': self.data.get('Symbol'),
            'timeframe': self.data.get('Timeframe')
        }
    
    def _extract_trades(self) -> List[Dict[str, Any]]:
        """Extract trade records"""
        trades = []
        
        # Adjust based on actual cTrader JSON structure
        trade_list = self.data.get('Trades', [])
        
        for trade in trade_list:
            trades.append({
                'trade_id': trade.get('Id'),
                'open_time': trade.get('OpenTime'),
                'close_time': trade.get('CloseTime'),
                'symbol': trade.get('Symbol'),
                'direction': trade.get('Direction'),
                'entry_price': trade.get('EntryPrice'),
                'exit_price': trade.get('ExitPrice'),
                'volume': trade.get('Volume'),
                'profit': trade.get('Profit'),
                'pips': trade.get('Pips'),
                'commission': trade.get('Commission'),
                'swap': trade.get('Swap'),
                'balance_after': trade.get('BalanceAfter')
            })
        
        return trades
    
    def _extract_parameters(self) -> Dict[str, Any]:
        """Extract bot parameters"""
        return self.data.get('Parameters', {})
    
    def _extract_summary(self) -> Dict[str, Any]:
        """Extract summary statistics"""
        return {
            'total_trades': self.data.get('TotalTrades', 0),
            'winning_trades': self.data.get('WinningTrades', 0),
            'losing_trades': self.data.get('LosingTrades', 0),
            'net_profit': self.data.get('NetProfit'),
            'profit_factor': self.data.get('ProfitFactor'),
            'sharpe_ratio': self.data.get('SharpeRatio'),
            'max_drawdown': self.data.get('MaxDrawdown')
        }

EOF

cat > ~/trading-ai-system/applications/data-pipeline/src/parsers/csv_parser.py << 'EOF'
"""
CSV parser for cTrader transaction logs
"""
import pandas as pd
import polars as pl
from typing import Dict, List, Any
from pathlib import Path
import logging


logger = logging.getLogger(__name__)




class CTraderCSVParser:
    """Parser for cTrader CSV transaction logs"""
    
    def __init__(self, file_path: str, use_polars: bool = True):
        self.file_path = Path(file_path)
        self.use_polars = use_polars  # Use Polars for large files
        self.data = None
        
    def parse(self) -> pd.DataFrame:
        """Parse CSV file and return DataFrame"""
        logger.info(f"Parsing CSV file: {self.file_path}")
        
        try:
            file_size_mb = self.file_path.stat().st_size / (1024 * 1024)
            logger.info(f"File size: {file_size_mb:.2f} MB")
            
            # Use Polars for large files (>100MB)
            if self.use_polars and file_size_mb > 100:
                logger.info("Using Polars for large file processing")
                df = self._parse_with_polars()
            else:
                logger.info("Using Pandas for file processing")
                df = self._parse_with_pandas()
            
            logger.info(f"Parsed {len(df)} records")
            return df
            
        except Exception as e:
            logger.error(f"Error parsing CSV: {e}")
            raise
    
    def _parse_with_pandas(self) -> pd.DataFrame:
        """Parse using Pandas"""
        df = pd.read_csv(
            self.file_path,
            parse_dates=['OpenTime', 'CloseTime'],
            dtype={
                'TradeId': str,
                'Symbol': str,
                'Direction': str,
                'EntryPrice': float,
                'ExitPrice': float,
                'Volume': float,
                'Profit': float,
                'Pips': float
            }
        )
        
        return self._clean_dataframe(df)
    
    def _parse_with_polars(self) -> pd.DataFrame:
        """Parse using Polars (faster for large files)"""
        df_polars = pl.read_csv(
            self.file_path,
            try_parse_dates=True
        )
        
        # Convert to Pandas for compatibility
        df = df_polars.to_pandas()
        
        return self._clean_dataframe(df)
    
    def _clean_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """Clean and standardize DataFrame"""
        # Rename columns to match database schema
        column_mapping = {
            'TradeId': 'trade_id',
            'PositionId': 'position_id',
            'OpenTime': 'open_time',
            'CloseTime': 'close_time',
            'Symbol': 'symbol',
            'Direction': 'direction',
            'EntryPrice': 'entry_price',
            'ExitPrice': 'exit_price',
            'Volume': 'volume',
            'Profit': 'profit',
            'Pips': 'pips',
            'Commission': 'commission',
            'Swap': 'swap',
            'StopLoss': 'stop_loss',
            'TakeProfit': 'take_profit',
            'BalanceAfter': 'balance_after'
        }
        
        # Rename columns that exist
        existing_columns = {k: v for k, v in column_mapping.items() if k in df.columns}
        df = df.rename(columns=existing_columns)
        
        # Calculate duration if both times are present
        if 'open_time' in df.columns and 'close_time' in df.columns:
            df['duration_seconds'] = (
                pd.to_datetime(df['close_time']) - pd.to_datetime(df['open_time'])
            ).dt.total_seconds()
        
        # Remove rows with missing critical data
        if 'open_time' in df.columns:
            df = df.dropna(subset=['open_time'])
        
        # Standardize direction values
        if 'direction' in df.columns:
            df['direction'] = df['direction'].str.upper()
        
        return df
    
    def validate(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Validate parsed data"""
        validation_results = {
            'total_records': len(df),
            'missing_values': df.isnull().sum().to_dict(),
            'invalid_directions': 0,
            'negative_volumes': 0,
            'date_range': None
        }
        
        # Check for invalid directions
        if 'direction' in df.columns:
            valid_directions = ['BUY', 'SELL']
            validation_results['invalid_directions'] = (
                ~df['direction'].isin(valid_directions)
            ).sum()
        
        # Check for negative volumes
        if 'volume' in df.columns:
            validation_results['negative_volumes'] = (df['volume'] < 0).sum()
        
        # Get date range
        if 'open_time' in df.columns:
            validation_results['date_range'] = {
                'start': df['open_time'].min(),
                'end': df['open_time'].max()
            }
        
        return validation_results

EOF

cat > ~/trading-ai-system/applications/data-pipeline/src/parsers/validator.py << 'EOF'
"""
Data validation utilities
"""
from typing import Dict, List, Any
import pandas as pd
import logging


logger = logging.getLogger(__name__)




class DataValidator:
    """Validates trading data before database insertion"""
    
    def __init__(self):
        self.errors = []
        self.warnings = []
    
    def validate_backtest_data(self, data: Dict[str, Any]) -> bool:
        """Validate complete backtest data"""
        logger.info("Validating backtest data")
        
        self.errors = []
        self.warnings = []
        
        # Validate backtest info
        self._validate_backtest_info(data.get('backtest_info', {}))
        
        # Validate trades
        if 'trades' in data:
            self._validate_trades(data['trades'])
        
        # Validate parameters
        if 'parameters' in data:
            self._validate_parameters(data['parameters'])
        
        if self.errors:
            logger.error(f"Validation failed with {len(self.errors)} errors")
            return False
        
        if self.warnings:
            logger.warning(f"Validation completed with {len(self.warnings)} warnings")
        
        logger.info("Validation successful")
        return True
    
    def _validate_backtest_info(self, info: Dict[str, Any]):
        """Validate backtest metadata"""
        required_fields = ['start_date', 'end_date', 'initial_balance']
        
        for field in required_fields:
            if field not in info or info[field] is None:
                self.errors.append(f"Missing required field: {field}")
        
        # Validate date range
        if 'start_date' in info and 'end_date' in info:
            if info['start_date'] >= info['end_date']:
                self.errors.append("Start date must be before end date")
        
        # Validate initial balance
        if 'initial_balance' in info:
            if info['initial_balance'] <= 0:
                self.errors.append("Initial balance must be positive")
    
    def _validate_trades(self, trades: List[Dict[str, Any]]):
        """Validate trade records"""
        if not trades:
            self.warnings.append("No trades found")
            return
        
        for idx, trade in enumerate(trades):
            # Check required fields
            required_fields = ['open_time', 'symbol', 'direction', 'entry_price', 'volume']
            
            for field in required_fields:
                if field not in trade or trade[field] is None:
                    self.errors.append(f"Trade {idx}: Missing {field}")
            
            # Validate direction
            if 'direction' in trade:
                if trade['direction'] not in ['BUY', 'SELL']:
                    self.errors.append(f"Trade {idx}: Invalid direction '{trade['direction']}'")
            
            # Validate prices
            if 'entry_price' in trade and trade['entry_price'] is not None:
                if trade['entry_price'] <= 0:
                    self.errors.append(f"Trade {idx}: Entry price must be positive")
            
            # Validate volume
            if 'volume' in trade and trade['volume'] is not None:
                if trade['volume'] <= 0:
                    self.errors.append(f"Trade {idx}: Volume must be positive")
            
            # Validate close time if present
            if 'close_time' in trade and trade['close_time'] is not None:
                if 'open_time' in trade and trade['open_time'] is not None:
                    if trade['close_time'] < trade['open_time']:
                        self.errors.append(f"Trade {idx}: Close time before open time")
    
    def _validate_parameters(self, parameters: Dict[str, Any]):
        """Validate bot parameters"""
        if not parameters:
            self.warnings.append("No parameters found")
            return
        
        # Check for common parameter issues
        for key, value in parameters.items():
            if value is None:
                self.warnings.append(f"Parameter '{key}' has null value")
    
    def get_validation_report(self) -> Dict[str, Any]:
        """Get validation report"""
        return {
            'is_valid': len(self.errors) == 0,
            'error_count': len(self.errors),
            'warning_count': len(self.warnings),
            'errors': self.errors,
            'warnings': self.warnings
        }

EOF

cat > ~/trading-ai-system/applications/data-pipeline/src/services/ingestion_service.py << 'EOF'
"""
Data ingestion service
"""
from sqlalchemy.orm import Session
from typing import Dict, Any, Optional
from uuid import UUID, uuid4
from datetime import datetime
from pathlib import Path
import logging
import shutil


from ..models.database import Backtest, Trade, Parameter, IngestionJob
from ..parsers.json_parser import CTraderJSONParser
from ..parsers.csv_parser import CTraderCSVParser
from ..parsers.validator import DataValidator
from ..config import settings


logger = logging.getLogger(__name__)




class IngestionService:
    """Service for ingesting trading data"""
    
    def __init__(self, db: Session):
        self.db = db
        self.validator = DataValidator()
    
    def ingest_backtest(
        self,
        name: str,
        json_file_path: str,
        csv_file_path: Optional[str] = None,
        parameters_file_path: Optional[str] = None,
        description: Optional[str] = None,
        initial_balance: float = 10000.00
    ) -> Dict[str, Any]:
        """
        Ingest complete backtest data
        
        Args:
            name: Backtest name
            json_file_path: Path to JSON results file
            csv_file_path: Optional path to CSV transactions file
            parameters_file_path: Optional path to parameters JSON
            description: Optional description
            initial_balance: Initial account balance
            
        Returns:
            Dict with backtest_id and job_id
        """
        logger.info(f"Starting ingestion for backtest: {name}")
        
        # Create ingestion job
        job = IngestionJob(
            job_type='full_ingestion',
            status='running',
            file_name=Path(json_file_path).name,
            started_at=datetime.utcnow()
        )
        self.db.add(job)
        self.db.commit()
        
        try:
            # Parse JSON file
            logger.info("Parsing JSON file")
            json_parser = CTraderJSONParser(json_file_path)
            data = json_parser.parse()
            
            # Validate data
            logger.info("Validating data")
            if not self.validator.validate_backtest_data(data):
                report = self.validator.get_validation_report()
                raise ValueError(f"Validation failed: {report['errors']}")
            
            # Create backtest record
            backtest = self._create_backtest(
                name=name,
                description=description,
                initial_balance=initial_balance,
                data=data
            )
            
            job.backtest_id = backtest.id
            
            # Store raw file
            raw_file_path = self._store_raw_file(json_file_path, backtest.id)
            backtest.raw_file_path = str(raw_file_path)
            
            # Insert trades
            logger.info("Inserting trades")
            trade_count = self._insert_trades(backtest.id, data['trades'])
            
            # Insert parameters
            logger.info("Inserting parameters")
            param_count = self._insert_parameters(backtest.id, data['parameters'])
            
            # Update backtest summary
            self._update_backtest_summary(backtest.id)
            
            # Mark backtest as completed
            backtest.status = 'completed'
            backtest.processed_at = datetime.utcnow()
            
            # Update job
            job.status = 'completed'
            job.completed_at = datetime.utcnow()
            job.duration_seconds = int(
                (job.completed_at - job.started_at).total_seconds()
            )
            job.records_total = trade_count
            job.records_processed = trade_count
            
            self.db.commit()
            
            logger.info(f"Ingestion completed: {trade_count} trades, {param_count} parameters")
            
            return {
                'backtest_id': str(backtest.id),
                'job_id': str(job.id),
                'trades_inserted': trade_count,
                'parameters_inserted': param_count
            }
            
        except Exception as e:
            logger.error(f"Ingestion failed: {e}")
            
            # Update job status
            job.status = 'failed'
            job.error_message = str(e)
            job.completed_at = datetime.utcnow()
            
            self.db.commit()
            
            raise
    
    def _create_backtest(
        self,
        name: str,
        initial_balance: float,
        data: Dict[str, Any],
        description: Optional[str] = None
    ) -> Backtest:
        """Create backtest record"""
        info = data['backtest_info']
        summary = data.get('summary', {})
        
        backtest = Backtest(
            name=name,
            description=description,
            start_date=info.get('start_date'),
            end_date=info.get('end_date'),
            initial_balance=initial_balance,
            status='processing'
        )
        
        self.db.add(backtest)
        self.db.commit()
        self.db.refresh(backtest)
        
        return backtest
    
    def _insert_trades(self, backtest_id: UUID, trades: list) -> int:
        """Insert trades in batches"""
        batch_size = settings.BATCH_SIZE
        total_inserted = 0
        
        for i in range(0, len(trades), batch_size):
            batch = trades[i:i + batch_size]
            
            trade_objects = [
                Trade(
                    backtest_id=backtest_id,
                    **trade
                )
                for trade in batch
            ]
            
            self.db.bulk_save_objects(trade_objects)
            self.db.commit()
            total_inserted += len(batch)
            logger.info(f"Inserted batch: {total_inserted}/{len(trades)} trades")
        
        return total_inserted
    
    def _insert_parameters(self, backtest_id: UUID, parameters: Dict[str, Any]) -> int:
        """Insert parameters"""
        if not parameters:
            return 0
        
        param_objects = []
        for key, value in parameters.items():
            param_objects.append(
                Parameter(
                    backtest_id=backtest_id,
                    parameter_name=key,
                    parameter_value=str(value),
                    parameter_type=type(value).__name__
                )
            )
        
        self.db.bulk_save_objects(param_objects)
        self.db.commit()
        
        return len(param_objects)
    
    def _update_backtest_summary(self, backtest_id: UUID):
        """Update backtest summary statistics"""
        # Call stored procedure
        self.db.execute(
            "SELECT calculate_backtest_summary(:backtest_id)",
            {'backtest_id': str(backtest_id)}
        )
        self.db.commit()
    
    def _store_raw_file(self, file_path: str, backtest_id: UUID) -> Path:
        """Store raw file in persistent storage"""
        source = Path(file_path)
        destination_dir = Path(settings.RAW_DATA_PATH) / str(backtest_id)
        destination_dir.mkdir(parents=True, exist_ok=True)
        
        destination = destination_dir / source.name
        shutil.copy2(source, destination)
        
        logger.info(f"Stored raw file: {destination}")
        return destination
    
    def get_job_status(self, job_id: UUID) -> Optional[IngestionJob]:
        """Get ingestion job status"""
        return self.db.query(IngestionJob).filter(
            IngestionJob.id == job_id
        ).first()

EOF

cat > ~/trading-ai-system/applications/data-pipeline/src/api/routes.py << 'EOF'
"""
FastAPI routes for data pipeline
"""
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from uuid import UUID
import tempfile
import logging


from ..models.database import get_db, Backtest, IngestionJob
from ..models.schemas import (
    BacktestResponse,
    IngestionRequest,
    IngestionResponse,
    JobStatus
)
from ..services.ingestion_service import IngestionService


logger = logging.getLogger(__name__)


router = APIRouter(prefix="/api/v1", tags=["data-pipeline"])




@router.post("/ingest", response_model=IngestionResponse)
async def ingest_data(
    json_file: UploadFile = File(..., description="cTrader JSON results file"),
    csv_file: Optional[UploadFile] = File(None, description="Transaction CSV file"),
    name: str = Form(..., description="Backtest name"),
    description: Optional[str] = Form(None, description="Backtest description"),
    initial_balance: float = Form(10000.00, description="Initial balance"),
    db: Session = Depends(get_db)
):
    """
    Ingest backtest data from cTrader exports
    
    Upload JSON and optionally CSV files to process backtest data
    """
    logger.info(f"Received ingestion request: {name}")
    
    # Validate file types
    if not json_file.filename.endswith('.json'):
        raise HTTPException(status_code=400, detail="JSON file must have .json extension")
    
    if csv_file and not csv_file.filename.endswith('.csv'):
        raise HTTPException(status_code=400, detail="CSV file must have .csv extension")
    
    try:
        # Save uploaded files to temporary location
        with tempfile.NamedTemporaryFile(delete=False, suffix='.json') as tmp_json:
            content = await json_file.read()
            tmp_json.write(content)
            tmp_json_path = tmp_json.name
        
        tmp_csv_path = None
        if csv_file:
            with tempfile.NamedTemporaryFile(delete=False, suffix='.csv') as tmp_csv:
                content = await csv_file.read()
                tmp_csv.write(content)
                tmp_csv_path = tmp_csv.name
        
        # Process ingestion
        service = IngestionService(db)
        result = service.ingest_backtest(
            name=name,
            json_file_path=tmp_json_path,
            csv_file_path=tmp_csv_path,
            description=description,
            initial_balance=initial_balance
        )
        
        return IngestionResponse(
            job_id=result['job_id'],
            backtest_id=result['backtest_id'],
            status='completed',
            message=f"Successfully ingested {result['trades_inserted']} trades"
        )
        
    except Exception as e:
        logger.error(f"Ingestion error: {e}")
        raise HTTPException(status_code=500, detail=str(e))




@router.get("/jobs/{job_id}", response_model=JobStatus)
def get_job_status(
    job_id: UUID,
    db: Session = Depends(get_db)
):
    """Get status of an ingestion job"""
    service = IngestionService(db)
    job = service.get_job_status(job_id)
    
    if not job:
        raise HTTPException(status_code=404, detail="Job not found")
    
    return job




@router.get("/backtests", response_model=List[BacktestResponse])
def list_backtests(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """List all backtests"""
    backtests = db.query(Backtest)\
        .order_by(Backtest.created_at.desc())\
        .offset(skip)\
        .limit(limit)\
        .all()
    
    return backtests




@router.get("/backtests/{backtest_id}", response_model=BacktestResponse)
def get_backtest(
    backtest_id: UUID,
    db: Session = Depends(get_db)
):
    """Get backtest details"""
    backtest = db.query(Backtest).filter(Backtest.id == backtest_id).first()
    
    if not backtest:
        raise HTTPException(status_code=404, detail="Backtest not found")
    
    return backtest




@router.delete("/backtests/{backtest_id}")
def delete_backtest(
    backtest_id: UUID,
    db: Session = Depends(get_db)
):
    """Delete a backtest and all related data"""
    backtest = db.query(Backtest).filter(Backtest.id == backtest_id).first()
    
    if not backtest:
        raise HTTPException(status_code=404, detail="Backtest not found")
    
    db.delete(backtest)
    db.commit()
    
    return {"message": "Backtest deleted successfully"}




@router.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "service": "data-pipeline"}

EOF

cat > ~/trading-ai-system/applications/data-pipeline/src/main.py << 'EOF'
"""
FastAPI application entry point
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import logging


from .config import settings
from .api.routes import router
from .models.database import engine, Base


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)


logger = logging.getLogger(__name__)


# Create tables
Base.metadata.create_all(bind=engine)


# Create FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="Data ingestion and processing pipeline for trading data"
)


# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Include routes
app.include_router(router)




@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")




@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Shutting down application")




@app.get("/")
def root():
    return {
        "service": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running"
    }

EOF

cat > ~/trading-ai-system/applications/data-pipeline/Dockerfile << 'EOF'
FROM python:3.11-slim


WORKDIR /app


# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*


# Copy requirements
COPY requirements.txt .


# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt


# Copy application code
COPY . .


# Create data directories
RUN mkdir -p /mnt/trading-data/raw /mnt/trading-data/processed


# Expose port
EXPOSE 8000


# Run application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
File: applications/data-pipeline/.env.example
# Application
APP_NAME=Trading AI Data Pipeline
APP_VERSION=1.0.0
DEBUG=False


# Database
DATABASE_URL=postgresql://trading_user:TradingAI2025!@postgres.databases.svc.cluster.local:5432/trading_db
DATABASE_POOL_SIZE=20
DATABASE_MAX_OVERFLOW=40


# File storage
RAW_DATA_PATH=/mnt/trading-data/raw
PROCESSED_DATA_PATH=/mnt/trading-data/processed


# Processing
MAX_FILE_SIZE_MB=500
BATCH_SIZE=10000


# API
API_HOST=0.0.0.0
API_PORT=8000

EOF

cat > ~/trading-ai-system/kubernetes/services/data-pipeline/deployment.yaml << 'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: data-pipeline-config
  namespace: trading-system
data:
  DATABASE_URL: "postgresql://trading_user:TradingAI2025!@postgres.databases.svc.cluster.local:5432/trading_db"
  RAW_DATA_PATH: "/mnt/trading-data/raw"
  PROCESSED_DATA_PATH: "/mnt/trading-data/processed"
  BATCH_SIZE: "10000"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: data-pipeline
  namespace: trading-system
  labels:
    app: data-pipeline
spec:
  replicas: 2
  selector:
    matchLabels:
      app: data-pipeline
  template:
    metadata:
      labels:
        app: data-pipeline
    spec:
      containers:
      - name: data-pipeline
        image: trading-ai/data-pipeline:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8000
          name: http
        envFrom:
        - configMapRef:
            name: data-pipeline-config
        volumeMounts:
        - name: trading-data
          mountPath: /mnt/trading-data
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: trading-data
        persistentVolumeClaim:
          claimName: trading-data-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: trading-data-pvc
  namespace: trading-system
spec:
  storageClassName: local-storage
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 500Gi
---
apiVersion: v1
kind: Service
metadata:
  name: data-pipeline
  namespace: trading-system
  labels:
    app: data-pipeline
spec:
  type: ClusterIP
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
    name: http
  selector:
    app: data-pipeline
---
apiVersion: v1
kind: Service
metadata:
  name: data-pipeline-nodeport
  namespace: trading-system
  labels:
    app: data-pipeline
spec:
  type: NodePort
  ports:
  - port: 8000
    targetPort: 8000
    nodePort: 30800
    protocol: TCP
    name: http
  selector:
    app: data-pipeline

EOF

cat > ~/trading-ai-system/scripts/build-data-pipeline.sh << 'EOF'
#!/bin/bash


set -e


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 Building Data Pipeline Docker Image"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


cd applications/data-pipeline


echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t trading-ai/data-pipeline:latest .


echo ""
echo -e "${GREEN}✓ Docker image built successfully${NC}"
echo ""
echo "Image: trading-ai/data-pipeline:latest"
echo ""

EOF

cat > ~/trading-ai-system/scripts/deploy-data-pipeline.sh << 'EOF'
#!/bin/bash


set -e


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deploying Data Pipeline Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


echo -e "${YELLOW}Step 1: Creating database schema${NC}"
POSTGRES_POD=$(kubectl get pod -n databases -l app=postgres -o jsonpath='{.items[0].metadata.name}')


kubectl exec -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db < applications/data-pipeline/schema/001_initial_schema.sql


echo -e "${GREEN}✓ Database schema created${NC}"
echo ""


echo -e "${YELLOW}Step 2: Building Docker image${NC}"
./scripts/build-data-pipeline.sh


echo ""
echo -e "${YELLOW}Step 3: Deploying to Kubernetes${NC}"
kubectl apply -f kubernetes/services/data-pipeline/deployment.yaml


echo ""
echo -e "${YELLOW}Step 4: Waiting for deployment...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/data-pipeline -n trading-system


echo ""
echo -e "${GREEN}✓ Data Pipeline deployed successfully${NC}"
echo ""


echo -e "${BLUE}Service Information:${NC}"
echo "  Internal: http://data-pipeline.trading-system.svc.cluster.local:8000"
echo "  External: http://localhost:30800"
echo ""
echo -e "${BLUE}API Documentation:${NC}"
echo "  Swagger UI: http://localhost:30800/docs"
echo "  ReDoc: http://localhost:30800/redoc"
echo ""


echo -e "${YELLOW}Testing endpoint...${NC}"
sleep 5
curl -s http://localhost:30800/health | jq '.'


echo ""
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo ""

EOF

cat > ~/trading-ai-system/scripts/test-data-pipeline.sh << 'EOF'
#!/bin/bash


set -e


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Testing Data Pipeline Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


API_URL="http://localhost:30800"
PASSED=0
FAILED=0


# Test function
test_endpoint() {
    local test_name=$1
    local endpoint=$2
    local expected_status=$3
    
    echo -e "${YELLOW}Testing: $test_name${NC}"
    
    status_code=$(curl -s -o /dev/null -w "%{http_code}" $API_URL$endpoint)
    
    if [ "$status_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✓ PASSED (Status: $status_code)${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ FAILED (Expected: $expected_status, Got: $status_code)${NC}"
        ((FAILED++))
    fi
    echo ""
}


# Run tests
test_endpoint "Health check" "/health" 200
test_endpoint "Root endpoint" "/" 200
test_endpoint "API docs" "/docs" 200
test_endpoint "List backtests" "/api/v1/backtests" 200


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Test Results Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""


if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi

EOF

cat > ~/trading-ai-system/docs/phase-guides/PHASE-2-data-pipeline.md << 'EOF'
# Phase 2: Data Pipeline & Storage


> Complete guide for building the data ingestion pipeline


**Duration**: 3-4 days  
**Difficulty**: Intermediate  
**Prerequisites**: Phase 1 completed


---


## 📋 Overview


Phase 2 builds the data ingestion and processing pipeline:


**What You'll Build**:
- ✅ Database schema for trading data
- ✅ JSON parser for cTrader exports
- ✅ CSV parser for transaction logs
- ✅ Data validation system
- ✅ FastAPI service for data ingestion
- ✅ Kubernetes deployment


**What You'll Learn**:
- Database schema design
- Data parsing and validation
- FastAPI development
- Docker containerization
- Kubernetes service deployment


---


## 🚀 Step-by-Step Guide


### Step 1: Create Database Schema


```bash
cd ~/trading-ai-system


# Connect to PostgreSQL
POSTGRES_POD=$(kubectl get pod -n databases -l app=postgres -o jsonpath='{.items[0].metadata.name}')


# Apply schema
kubectl exec -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db < applications/data-pipeline/schema/001_initial_schema.sql
Verify schema creation:


-----------------------------------0-----------------------------------------
kubectl exec -it -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db


# List tables
\dt


# Expected output:
# backtests
# trades
# parameters
# daily_summary
# ingestion_jobs


# Exit
\q
Step 2: Build Docker Image
-----------------------------------0-----------------------------------------
chmod +x scripts/build-data-pipeline.sh
./scripts/build-data-pipeline.sh
Expected output:


-----------------------------------...-----------------------------------------
🔨 Building Data Pipeline Docker Image
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


Building Docker image...
[+] Building 45.2s (12/12) FINISHED
✓ Docker image built successfully


Image: trading-ai/data-pipeline:latest
Step 3: Deploy to Kubernetes
-----------------------------------0-----------------------------------------
chmod +x scripts/deploy-data-pipeline.sh
./scripts/deploy-data-pipeline.sh
Expected output:


-----------------------------------...-----------------------------------------
🚀 Deploying Data Pipeline Service
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


Step 1: Creating database schema
✓ Database schema created


Step 2: Building Docker image
✓ Docker image built successfully


Step 3: Deploying to Kubernetes
deployment.apps/data-pipeline created
service/data-pipeline created


Step 4: Waiting for deployment...
deployment.apps/data-pipeline condition met


✓ Data Pipeline deployed successfully


Service Information:
  Internal: http://data-pipeline.trading-system.svc.cluster.local:8000
  External: http://localhost:30800


API Documentation:
  Swagger UI: http://localhost:30800/docs
  ReDoc: http://localhost:30800/redoc


✅ Deployment Complete!
Step 4: Verify Deployment
-----------------------------------0-----------------------------------------
# Check pods
kubectl get pods -n trading-system


# Expected output:
# NAME                             READY   STATUS    RESTARTS   AGE
# data-pipeline-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
# data-pipeline-xxxxxxxxxx-xxxxx   1/1     Running   0          2m


# Check service
kubectl get svc -n trading-system data-pipeline


# Test API
curl http://localhost:30800/health
Step 5: Run Tests
-----------------------------------0-----------------------------------------
chmod +x scripts/test-data-pipeline.sh
./scripts/test-data-pipeline.sh
Expected output:


-----------------------------------...-----------------------------------------
🧪 Testing Data Pipeline Service
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


Testing: Health check
✓ PASSED (Status: 200)


Testing: Root endpoint
✓ PASSED (Status: 200)


Testing: API docs
✓ PASSED (Status: 200)


Testing: List backtests
✓ PASSED (Status: 200)


━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test Results Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━


Passed: 4
Failed: 0


✅ All tests passed!
💻 Usage Examples
Example 1: Upload Backtest Data via API
Using curl:


-----------------------------------0-----------------------------------------
curl -X POST "http://localhost:30800/api/v1/ingest" \
  -F "json_file=@/path/to/results.json" \
  -F "name=My First Backtest" \
  -F "description=10-year EMA strategy" \
  -F "initial_balance=10000"
Expected response:


json
-----------------------------------...-----------------------------------------
{
  "job_id": "123e4567-e89b-12d3-a456-426614174000",
  "backtest_id": "123e4567-e89b-12d3-a456-426614174001",
  "status": "completed",
  "message": "Successfully ingested 15234 trades"
}
Example 2: Using Python Client
python
-----------------------------------...-----------------------------------------
import requests


# Upload files
url = "http://localhost:30800/api/v1/ingest"


files = {
    'json_file': open('results.json', 'rb'),
    'csv_file': open('transactions.csv', 'rb')
}


data = {
    'name': 'My Backtest',
    'description': 'Test backtest',
    'initial_balance': 10000.00
}


response = requests.post(url, files=files, data=data)
print(response.json())


# Get backtest details
backtest_id = response.json()['backtest_id']
backtest = requests.get(f"{url}/backtests/{backtest_id}")
print(backtest.json())
Example 3: Query Database Directly
-----------------------------------0-----------------------------------------
# Connect to PostgreSQL
kubectl exec -it -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db
List all backtests:


sql
-----------------------------------...-----------------------------------------
SELECT id, name, total_trades, win_rate, net_profit, created_at
FROM backtests
ORDER BY created_at DESC
LIMIT 10;
Get trades for a specific backtest:


sql
-----------------------------------...-----------------------------------------
SELECT 
    open_time,
    symbol,
    direction,
    entry_price,
    exit_price,
    profit,
    pips
FROM trades
WHERE backtest_id = 'your-backtest-id'
ORDER BY open_time
LIMIT 100;
Daily performance summary:


sql
-----------------------------------...-----------------------------------------
SELECT 
    trade_date,
    total_trades,
    winning_trades,
    net_profit,
    win_rate
FROM daily_summary
WHERE backtest_id = 'your-backtest-id'
ORDER BY trade_date;
Top performing symbols:


sql
-----------------------------------...-----------------------------------------
SELECT 
    symbol,
    COUNT(*) as trade_count,
    SUM(profit) as total_profit,
    AVG(profit) as avg_profit,
    ROUND(AVG(CASE WHEN profit > 0 THEN 1 ELSE 0 END) * 100, 2) as win_rate
FROM trades
WHERE backtest_id = 'your-backtest-id'
GROUP BY symbol
ORDER BY total_profit DESC;
🐛 Troubleshooting
Issue 1: Schema Creation Fails
Symptoms:


-----------------------------------...-----------------------------------------
ERROR: relation "backtests" already exists
Solution:


-----------------------------------0-----------------------------------------
# Drop and recreate schema
kubectl exec -it -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db


DROP TABLE IF EXISTS trades CASCADE;
DROP TABLE IF EXISTS backtests CASCADE;
DROP TABLE IF EXISTS parameters CASCADE;
DROP TABLE IF EXISTS daily_summary CASCADE;
DROP TABLE IF EXISTS ingestion_jobs CASCADE;


\q


# Reapply schema
kubectl exec -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db < applications/data-pipeline/schema/001_initial_schema.sql
Issue 2: Pod Not Starting
Symptoms:


-----------------------------------...-----------------------------------------
kubectl get pods -n trading-system
# Shows CrashLoopBackOff or Error
Solution:


-----------------------------------0-----------------------------------------
# Check logs
kubectl logs -n trading-system deployment/data-pipeline


# Common issues:
# 1. Database connection failed
# Check DATABASE_URL in configmap


# 2. Missing dependencies
# Rebuild Docker image


# 3. Port already in use
# Check if NodePort 30800 is available
Issue 3: File Upload Fails
Symptoms:


-----------------------------------...-----------------------------------------
{"detail":"File too large"}
Solution:


-----------------------------------0-----------------------------------------
# Increase file size limit
kubectl edit configmap data-pipeline-config -n trading-system


# Add:
MAX_FILE_SIZE_MB: "1000"


# Restart deployment
kubectl rollout restart deployment/data-pipeline -n trading-system
## ✅ Phase 2 Checklist


- [ ] Database schema created
- [ ] Docker image built
- [ ] Service deployed to Kubernetes
- [ ] All tests passing
- [ ] API accessible at http://localhost:30800
- [ ] Can upload test file successfully
- [ ] Database queries working
- [ ] Swagger docs accessible


**When all items are checked, Phase 2 is complete!** 🎉


---


## 📊 What You've Built


### Database Tables


1. **backtests** - Stores backtest metadata and summary
2. **trades** - Individual trade records
3. **parameters** - Bot parameters
4. **daily_summary** - Daily aggregated performance
5. **ingestion_jobs** - Tracks data ingestion jobs


### API Endpoints


- `POST /api/v1/ingest` - Upload backtest data
- `GET /api/v1/backtests` - List all backtests
- `GET /api/v1/backtests/{id}` - Get backtest details
- `GET /api/v1/jobs/{id}` - Get job status
- `DELETE /api/v1/backtests/{id}` - Delete backtest
- `GET /health` - Health check


### Services


- **Data Pipeline API** - FastAPI service for data ingestion
- **PostgreSQL** - Structured data storage
- **File Storage** - Raw file persistence


---


## 🎯 Next Steps


### Immediate Actions


1. **Upload Your First Backtest**:
```bash
# Prepare your cTrader export files
# - results.json
# - transactions.csv (optional)
# - parameters.json (optional)


# Upload via API
curl -X POST "http://localhost:30800/api/v1/ingest" \
  -F "json_file=@results.json" \
  -F "name=My First Backtest" \
  -F "initial_balance=10000"
Explore the Data:
-----------------------------------0-----------------------------------------
# Access Swagger UI
# Open browser: http://localhost:30800/docs


# Or query database directly
kubectl exec -it -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db
Create a Backup:
-----------------------------------0-----------------------------------------
./infrastructure/scripts/backup.sh
Proceed to Phase 3
Once you have successfully ingested data, you're ready for Phase 3: RAG System


Phase 3 will cover:


Setting up ChromaDB collections
Generating embeddings from trade data
Building the RAG query system
Integrating with Ollama LLM
Natural language queries over your data
📚 Additional Resources
API Documentation
Access the interactive API documentation:


Swagger UI: http://localhost:30800/docs
ReDoc: http://localhost:30800/redoc
Database Schema Reference
See applications/data-pipeline/schema/001_initial_schema.sql for complete schema definition.


Example Queries
Common SQL queries for analyzing your data:


Total profit by month:


sql
-----------------------------------...-----------------------------------------
SELECT 
    DATE_TRUNC('month', open_time) as month,
    COUNT(*) as trades,
    SUM(profit) as total_profit
FROM trades
WHERE backtest_id = 'your-id'
GROUP BY month
ORDER BY month;
Win rate by day of week:


sql
-----------------------------------...-----------------------------------------
SELECT 
    TO_CHAR(open_time, 'Day') as day_of_week,
    COUNT(*) as total_trades,
    SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END) as winning_trades,
    ROUND(AVG(CASE WHEN profit > 0 THEN 1 ELSE 0 END) * 100, 2) as win_rate
FROM trades
WHERE backtest_id = 'your-id'
GROUP BY day_of_week, EXTRACT(DOW FROM open_time)
ORDER BY EXTRACT(DOW FROM open_time);
Drawdown analysis:


sql
-----------------------------------...-----------------------------------------
SELECT 
    open_time,
    balance_after,
    drawdown,
    drawdown_percent
FROM trades
WHERE backtest_id = 'your-id'
ORDER BY drawdown_percent DESC
LIMIT 20;
🔄 Maintenance
Regular Tasks
Daily:


Monitor API health: curl http://localhost:30800/health
Check pod status: kubectl get pods -n trading-system
Weekly:


Review ingestion jobs: Check for failed jobs in database
Database maintenance: Run VACUUM ANALYZE on large tables
Backup: Create weekly backup
Monthly:


Clean old ingestion jobs
Archive old backtest data if needed
Review disk usage
Monitoring Queries
Check ingestion job status:


sql
-----------------------------------...-----------------------------------------
SELECT 
    status,
    COUNT(*) as count
FROM ingestion_jobs
GROUP BY status;
Recent failed jobs:


sql
-----------------------------------...-----------------------------------------
SELECT 
    id,
    job_type,
    error_message,
    created_at
FROM ingestion_jobs
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 10;
Database size:


sql
-----------------------------------...-----------------------------------------
SELECT 
    pg_size_pretty(pg_database_size('trading_db')) as database_size;
Next: Phase 3: RAG System


-----------------------------------...-----------------------------------------


---


### **File: `README-PHASE-2.md`**


```markdown
# Phase 2: Data Pipeline - Quick Reference


## Files Created


### Application Code
- `applications/data-pipeline/requirements.txt`
- `applications/data-pipeline/Dockerfile`
- `applications/data-pipeline/.env.example`
- `applications/data-pipeline/src/config.py`
- `applications/data-pipeline/src/main.py`
- `applications/data-pipeline/src/models/database.py`
- `applications/data-pipeline/src/models/schemas.py`
- `applications/data-pipeline/src/parsers/json_parser.py`
- `applications/data-pipeline/src/parsers/csv_parser.py`
- `applications/data-pipeline/src/parsers/validator.py`
- `applications/data-pipeline/src/services/ingestion_service.py`
- `applications/data-pipeline/src/api/routes.py`


### Database
- `applications/data-pipeline/schema/001_initial_schema.sql`


### Kubernetes
- `kubernetes/services/data-pipeline/deployment.yaml`


### Scripts
- `scripts/build-data-pipeline.sh`
- `scripts/deploy-data-pipeline.sh`
- `scripts/test-data-pipeline.sh`


### Documentation
- `docs/phase-guides/PHASE-2-data-pipeline.md`


---


## Quick Start


```bash
# 1. Deploy data pipeline
./scripts/deploy-data-pipeline.sh


# 2. Test deployment
./scripts/test-data-pipeline.sh


# 3. Upload data
curl -X POST "http://localhost:30800/api/v1/ingest" \
  -F "json_file=@results.json" \
  -F "name=Test Backtest" \
  -F "initial_balance=10000"


# 4. View API docs
# Open: http://localhost:30800/docs
Service Endpoints
API: http://localhost:30800
Health: http://localhost:30800/health
Docs: http://localhost:30800/docs
ReDoc: http://localhost:30800/redoc
Database Access
-----------------------------------0-----------------------------------------
# Connect to PostgreSQL
POSTGRES_POD=$(kubectl get pod -n databases -l app=postgres -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db


# List tables
\dt


# Query backtests
SELECT * FROM backtests ORDER BY created_at DESC LIMIT 5;
Common Commands
-----------------------------------0-----------------------------------------
# View logs
kubectl logs -f deployment/data-pipeline -n trading-system


# Restart service
kubectl rollout restart deployment/data-pipeline -n trading-system


# Scale replicas
kubectl scale deployment/data-pipeline --replicas=3 -n trading-system


# Delete service
kubectl delete -f kubernetes/services/data-pipeline/deployment.yaml
Troubleshooting
Pod not starting?


-----------------------------------0-----------------------------------------
kubectl describe pod -n trading-system -l app=data-pipeline
kubectl logs -n trading-system -l app=data-pipeline
Database connection issues?


-----------------------------------0-----------------------------------------
# Test database connectivity
kubectl exec -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db -c "SELECT 1;"
API not responding?


-----------------------------------0-----------------------------------------
# Check service
kubectl get svc -n trading-system data-pipeline


# Port forward
kubectl port-forward -n trading-system svc/data-pipeline 8000:8000
# Then access: http://localhost:8000
-----------------------------------...-----------------------------------------


---


**✅ PHASE 2 COMPLETE!**


---


## 📊 Phase 2 Summary


You now have:


1. ✅ **Database Schema** - 5 tables for trading data
2. ✅ **JSON Parser** - Parse cTrader exports
3. ✅ **CSV Parser** - Handle large transaction logs
4. ✅ **Data Validator** - Ensure data quality
5. ✅ **FastAPI Service** - RESTful API for data ingestion
6. ✅ **Kubernetes Deployment** - Scalable service deployment
7. ✅ **API Documentation** - Interactive Swagger UI


**Total Files Created**: 20+ files


---


**Ready to proceed to Phase 3?** Type "**phase 3**" or "**done**" if you want to stop here.

EOF

cat > ~/trading-ai-system/applications/data-pipeline/README.md << 'EOF'
# Data Pipeline Service


FastAPI service for ingesting and processing cTrader backtest data.


## Features


- Parse cTrader JSON exports
- Parse transaction CSV files
- Data validation
- Batch processing for large datasets
- RESTful API
- PostgreSQL storage


## Local Development


### Setup


```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate


# Install dependencies
pip install -r requirements.txt


# Copy environment file
cp .env.example .env


# Edit .env with your settings
Run Locally
-----------------------------------0-----------------------------------------
# Start the service
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000


# Access API docs
# http://localhost:8000/docs
Run Tests
-----------------------------------0-----------------------------------------
pytest
Docker
Build
-----------------------------------0-----------------------------------------
docker build -t trading-ai/data-pipeline:latest .
Run
-----------------------------------0-----------------------------------------
docker run -p 8000:8000 \
  -e DATABASE_URL="postgresql://user:pass@host/db" \
  trading-ai/data-pipeline:latest
API Endpoints
Upload Data
-----------------------------------...-----------------------------------------
POST /api/v1/ingest
List Backtests
-----------------------------------...-----------------------------------------
GET /api/v1/backtests
Get Backtest
-----------------------------------...-----------------------------------------
GET /api/v1/backtests/{id}
Get Job Status
-----------------------------------...-----------------------------------------
GET /api/v1/jobs/{id}
Delete Backtest
-----------------------------------...-----------------------------------------
DELETE /api/v1/backtests/{id}
Database Schema
See schema/001_initial_schema.sql for complete schema.


Tables
backtests - Backtest metadata and summary
trades - Individual trade records
parameters - Bot parameters
daily_summary - Daily performance aggregation
ingestion_jobs - Job tracking
Configuration
Environment variables:


-----------------------------------0-----------------------------------------
DATABASE_URL=postgresql://user:pass@host:5432/db
RAW_DATA_PATH=/mnt/trading-data/raw
PROCESSED_DATA_PATH=/mnt/trading-data/processed
BATCH_SIZE=10000
MAX_FILE_SIZE_MB=500
Architecture
-----------------------------------...-----------------------------------------
Client → FastAPI → Parser → Validator → Database
                  ↓
              File Storage
-----------------------------------...-----------------------------------------


---


### **File: `applications/data-pipeline/tests/test_parsers.py`**


```python
"""
Tests for data parsers
"""
import pytest
from src.parsers.json_parser import CTraderJSONParser
from src.parsers.validator import DataValidator




def test_json_parser():
    """Test JSON parser basic functionality"""
    # This is a placeholder test
    # In real implementation, you would use actual test data
    validator = DataValidator()
    assert validator is not None




def test_data_validator():
    """Test data validator"""
    validator = DataValidator()
    
    # Test with valid data
    valid_data = {
        'backtest_info': {
            'start_date': '2024-01-01',
            'end_date': '2024-12-31',
            'initial_balance': 10000.00
        },
        'trades': [
            {
                'open_time': '2024-01-01 10:00:00',
                'symbol': 'EURUSD',
                'direction': 'BUY',
                'entry_price': 1.1000,
                'volume': 0.01
            }
        ],
        'parameters': {}
    }
    
    result = validator.validate_backtest_data(valid_data)
    assert result is True
    
    # Test with invalid data
    invalid_data = {
        'backtest_info': {
            'start_date': '2024-12-31',
            'end_date': '2024-01-01',  # End before start
            'initial_balance': -1000  # Negative balance
        },
        'trades': [],
        'parameters': {}
    }
    
    result = validator.validate_backtest_data(invalid_data)
    assert result is False

EOF

cat > ~/trading-ai-system/.dockerignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
*.egg-info/
dist/
build/


# Testing
.pytest_cache/
.coverage
htmlcov/


# IDE
.vscode/
.idea/
*.swp


# Environment
.env
.env.local


# Git
.git/
.gitignore


# Documentation
*.md
docs/


# Tests
tests/
*.test.py


# Misc
*.log
.DS_Store

EOF

cat > ~/trading-ai-system/Makefile << 'EOF'
# Trading AI System - Makefile


.PHONY: help setup deploy-infra deploy-pipeline test clean


help:
	@echo "Trading AI System - Available Commands"
	@echo ""
	@echo "Setup:"
	@echo "  make setup              - Run initial system setup"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy-infra       - Deploy infrastructure (Phase 1)"
	@echo "  make deploy-pipeline    - Deploy data pipeline (Phase 2)"
	@echo "  make deploy-all         - Deploy everything"
	@echo ""
	@echo "Testing:"
	@echo "  make test-infra         - Test infrastructure"
	@echo "  make test-pipeline      - Test data pipeline"
	@echo "  make test-all           - Run all tests"
	@echo ""
	@echo "Maintenance:"
	@echo "  make backup             - Create system backup"
	@echo "  make logs               - View application logs"
	@echo "  make clean              - Clean up resources"
	@echo ""


setup:
	@echo "Running system setup..."
	chmod +x infrastructure/scripts/setup-master.sh
	./infrastructure/scripts/setup-master.sh


deploy-infra:
	@echo "Deploying infrastructure..."
	chmod +x infrastructure/scripts/deploy-infrastructure.sh
	./infrastructure/scripts/deploy-infrastructure.sh


deploy-pipeline:
	@echo "Deploying data pipeline..."
	chmod +x scripts/deploy-data-pipeline.sh
	./scripts/deploy-data-pipeline.sh


deploy-all: deploy-infra deploy-pipeline
	@echo "Full deployment complete!"


test-infra:
	@echo "Testing infrastructure..."
	chmod +x infrastructure/scripts/test-infrastructure.sh
	./infrastructure/scripts/test-infrastructure.sh


test-pipeline:
	@echo "Testing data pipeline..."
	chmod +x scripts/test-data-pipeline.sh
	./scripts/test-data-pipeline.sh


test-all: test-infra test-pipeline
	@echo "All tests complete!"


backup:
	@echo "Creating backup..."
	chmod +x infrastructure/scripts/backup.sh
	./infrastructure/scripts/backup.sh


logs:
	@echo "Viewing logs..."
	kubectl logs -f deployment/data-pipeline -n trading-system


clean:
	@echo "Cleaning up..."
	kubectl delete -f kubernetes/services/data-pipeline/deployment.yaml || true
	docker system prune -f


status:
	@echo "System Status:"
	@echo ""
	@echo "Nodes:"
	kubectl get nodes
	@echo ""
	@echo "Pods:"
	kubectl get pods -A
	@echo ""
	@echo "Services:"
	kubectl get svc -A

EOF

cat > ~/trading-ai-system/scripts/upload-sample-data.sh << 'EOF'
#!/bin/bash


set -e


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 Upload Sample Data to Data Pipeline"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


# Check if file argument provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: No file specified${NC}"
    echo ""
    echo "Usage: $0 <json-file> [csv-file]"
    echo ""
    echo "Example:"
    echo "  $0 results.json"
    echo "  $0 results.json transactions.csv"
    exit 1
fi


JSON_FILE=$1
CSV_FILE=$2


# Check if JSON file exists
if [ ! -f "$JSON_FILE" ]; then
    echo -e "${RED}Error: File not found: $JSON_FILE${NC}"
    exit 1
fi


echo -e "${YELLOW}Uploading backtest data...${NC}"
echo ""
echo "JSON file: $JSON_FILE"
if [ -n "$CSV_FILE" ]; then
    echo "CSV file: $CSV_FILE"
fi
echo ""


# Build curl command
CURL_CMD="curl -X POST http://localhost:30800/api/v1/ingest"
CURL_CMD="$CURL_CMD -F json_file=@$JSON_FILE"


if [ -n "$CSV_FILE" ]; then
    CURL_CMD="$CURL_CMD -F csv_file=@$CSV_FILE"
fi


CURL_CMD="$CURL_CMD -F name=Uploaded_$(date +%Y%m%d_%H%M%S)"
CURL_CMD="$CURL_CMD -F description=Uploaded via script"
CURL_CMD="$CURL_CMD -F initial_balance=10000"


# Execute upload
echo -e "${YELLOW}Uploading...${NC}"
RESPONSE=$(eval $CURL_CMD)


echo ""
echo -e "${GREEN}Response:${NC}"
echo $RESPONSE | jq '.'


# Extract backtest_id
BACKTEST_ID=$(echo $RESPONSE | jq -r '.backtest_id')


if [ "$BACKTEST_ID" != "null" ]; then
    echo ""
    echo -e "${GREEN}✅ Upload successful!${NC}"
    echo ""
    echo "Backtest ID: $BACKTEST_ID"
    echo ""
    echo "View details:"
    echo "  curl http://localhost:30800/api/v1/backtests/$BACKTEST_ID | jq '.'"
else
    echo ""
    echo -e "${RED}❌ Upload failed${NC}"
    exit 1
fi

EOF

cat > ~/trading-ai-system/scripts/query-backtest.sh << 'EOF'
#!/bin/bash


set -e


echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Query Backtest Data"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""


# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


POSTGRES_POD=$(kubectl get pod -n databases -l app=postgres -o jsonpath='{.items[0].metadata.name}')


if [ -z "$1" ]; then
    echo -e "${YELLOW}Listing all backtests:${NC}"
    echo ""
    kubectl exec -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db -c "
        SELECT 
            id,
            name,
            total_trades,
            win_rate,
            net_profit,
            created_at
        FROM backtests
        ORDER BY created_at DESC
        LIMIT 10;
    "
else
    BACKTEST_ID=$1
    echo -e "${YELLOW}Backtest Details: $BACKTEST_ID${NC}"
    echo ""
    
    echo -e "${BLUE}Summary:${NC}"
    kubectl exec -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db -c "
        SELECT * FROM backtests WHERE id = '$BACKTEST_ID';
    "
    
    echo ""
    echo -e "${BLUE}Trade Statistics:${NC}"
    kubectl exec -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db -c "
        SELECT 
            COUNT(*) as total_trades,
            SUM(CASE WHEN profit > 0 THEN 1 ELSE 0 END) as winning_trades,
            SUM(CASE WHEN profit < 0 THEN 1 ELSE 0 END) as losing_trades,
            SUM(profit) as total_profit,
            AVG(profit) as avg_profit,
            MAX(profit) as max_profit,
            MIN(profit) as min_profit
        FROM trades
        WHERE backtest_id = '$BACKTEST_ID';
    "
    
    echo ""
    echo -e "${BLUE}Top 10 Trades:${NC}"
    kubectl exec -n databases $POSTGRES_POD -- psql -U trading_user -d trading_db -c "
        SELECT 
            open_time,
            symbol,
            direction,
            profit,
            pips
        FROM trades
        WHERE backtest_id = '$BACKTEST_ID'
        ORDER BY profit DESC
        LIMIT 10;
    "
fi

EOF

cat > ~/trading-ai-system/applications/data-pipeline/tests/test_parsers.py << 'EOF'
import pytest
from src.parsers.json_parser import CTraderJSONParser
from src.parsers.validator import DataValidator




def test_json_parser():
    """Test JSON parser basic functionality"""
    # This is a placeholder test
    # In real implementation, you would use actual test data
    validator = DataValidator()
    assert validator is not None




def test_data_validator():
    """Test data validator"""
    validator = DataValidator()
    
    # Test with valid data
    valid_data = {
        'backtest_info': {
            'start_date': '2024-01-01',
            'end_date': '2024-12-31',
            'initial_balance': 10000.00
        },
        'trades': [
            {
                'open_time': '2024-01-01 10:00:00',
                'symbol': 'EURUSD',
                'direction': 'BUY',
                'entry_price': 1.1000,
                'volume': 0.01
            }
        ],
        'parameters': {}
    }
    
    result = validator.validate_backtest_data(valid_data)
    assert result is True
    
    # Test with invalid data
    invalid_data = {
        'backtest_info': {
            'start_date': '2024-12-31',
            'end_date': '2024-01-01',  # End before start
            'initial_balance': -1000  # Negative balance
        },
        'trades': [],
        'parameters': {}
    }
    
    result = validator.validate_backtest_data(invalid_data)
    assert result is False

EOF
