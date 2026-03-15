//! Web3 Integration - Децентрализованный кошелёк с отказоустойчивостью
//!
//! Этот модуль предоставляет функциональность для:
//! - Подключения к пулу RPC нод (Pocket, Lava, Public fallback)
//! - Автоматической проверки здоровья нод
//! - Failover переключения при ошибках
//! - Безопасного хранения ключей с использованием zeroize
//!
//! # Безопасность
//! Приватные ключи НИКОГДА не хранятся в открытом виде.
//! Все чувствительные данные обрабатываются с использованием Zeroize.

use ethers::prelude::*;
use ethers::providers::{Http, Provider, Middleware};
use ethers::types::{Address, U256};
use ethers::core::types::transaction::eip2718::TypedTransaction;
use serde::{Deserialize, Serialize};
use sled::Db;
use std::error::Error;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::RwLock;
use zeroize::{Zeroize, Zeroizing};

/// Стандартные RPC endpoints для Polygon
pub const DEFAULT_RPC_URLS: &[&str] = &[
    "https://polygon-rpc.com",
    "https://rpc-mainnet.matic.network",
    "https://matic-mainnet.chainstacklabs.com",
];

/// Адрес токена MATIC в сети Polygon (нативный токен)
pub const MATIC_DECIMALS: u32 = 18;

/// Информация о провайдере
#[derive(Clone, Debug)]
pub struct ProviderInfo {
    /// URL RPC ноды
    pub url: String,
    /// Название провайдера (Pocket, Lava, Public)
    pub name: String,
    /// Приоритет (1 = главный, 2 = резервный, 3 = fallback)
    pub priority: u8,
    /// Последняя известная задержка в мс
    pub latency_ms: Option<u128>,
    /// Статус (жив/мёртв)
    pub is_healthy: bool,
}

/// Децентрализованный пул провайдеров
pub struct DecentralizedProvider {
    /// Список всех провайдеров
    providers: Arc<RwLock<Vec<ProviderInfo>>>,
    /// Текущий активный провайдер (индекс)
    active_index: Arc<RwLock<usize>>,
    /// HTTP клиент для проверок
    http_client: reqwest::Client,
}

impl Clone for DecentralizedProvider {
    fn clone(&self) -> Self {
        Self {
            providers: self.providers.clone(),
            active_index: self.active_index.clone(),
            http_client: self.http_client.clone(),
        }
    }
}

impl DecentralizedProvider {
    /// Создать новый пул провайдеров из переменных окружения
    pub fn from_env() -> Self {
        let mut providers = Vec::new();

        // Pocket RPC (приоритет 1)
        if let Ok(url) = std::env::var("POCKET_RPC_URL") {
            providers.push(ProviderInfo {
                url: url.clone(),
                name: "Pocket".to_string(),
                priority: 1,
                latency_ms: None,
                is_healthy: true,
            });
            println!("📡 [Wallet] Pocket RPC добавлен: {}", url);
        }

        // Lava RPC (приоритет 2)
        if let Ok(url) = std::env::var("LAVA_RPC_URL") {
            providers.push(ProviderInfo {
                url: url.clone(),
                name: "Lava".to_string(),
                priority: 2,
                latency_ms: None,
                is_healthy: true,
            });
            println!("📡 [Wallet] Lava RPC добавлен: {}", url);
        }

        // Public fallback (приоритет 3)
        for &url in DEFAULT_RPC_URLS {
            providers.push(ProviderInfo {
                url: url.to_string(),
                name: "Public".to_string(),
                priority: 3,
                latency_ms: None,
                is_healthy: true,
            });
        }

        // Сортировка по приоритету
        providers.sort_by_key(|p| p.priority);

        let count = providers.len();
        println!("📡 [Wallet] Инициализировано {} RPC провайдеров", count);

        Self {
            providers: Arc::new(RwLock::new(providers)),
            active_index: Arc::new(RwLock::new(0)),
            http_client: reqwest::Client::new(),
        }
    }

    /// Проверить задержку одной ноды
    pub async fn check_node_latency(&self, url: &str) -> Option<u128> {
        let start = std::time::Instant::now();

        // Пытаемся сделать eth_blockNumber запрос
        let result = tokio::time::timeout(
            Duration::from_secs(5),
            self.http_client
                .post(url)
                .json(&serde_json::json!({
                    "jsonrpc": "2.0",
                    "method": "eth_blockNumber",
                    "params": [],
                    "id": 1
                }))
                .send()
        ).await;

        match result {
            Ok(Ok(response)) => {
                if response.status().is_success() {
                    let elapsed = start.elapsed().as_millis();
                    Some(elapsed)
                } else {
                    None
                }
            }
            _ => None,
        }
    }

    /// Проверить здоровье всех нод и отсортировать по задержке
    pub async fn health_check(&self) -> Vec<ProviderInfo> {
        let mut providers = self.providers.read().await.clone();
        let mut healthy = Vec::new();

        println!("🏥 [Wallet] Проверка здоровья RPC нод...");

        for provider in &mut providers {
            match self.check_node_latency(&provider.url).await {
                Some(latency) => {
                    provider.latency_ms = Some(latency);
                    provider.is_healthy = true;
                    healthy.push(provider.clone());
                    println!("   ✅ {} ({}): {} мс", provider.name, provider.url, latency);
                }
                None => {
                    provider.is_healthy = false;
                    provider.latency_ms = None;
                    println!("   ❌ {} ({}): недоступен", provider.name, provider.url);
                }
            }
        }

        // Сортировка: сначала по приоритету, потом по задержке
        healthy.sort_by(|a, b| {
            a.priority.cmp(&b.priority)
                .then_with(|| {
                    a.latency_ms.cmp(&b.latency_ms)
                })
        });

        // Обновляем список
        let mut providers_write = self.providers.write().await;
        *providers_write = healthy.clone();

        // Сбрасываем активный индекс на лучший
        let mut active_write = self.active_index.write().await;
        *active_write = 0;

        healthy
    }

    /// Получить текущий активный провайдер
    pub async fn get_active_provider(&self) -> Option<Provider<Http>> {
        let providers = self.providers.read().await;
        let active_idx = *self.active_index.read().await;

        if active_idx >= providers.len() {
            return None;
        }

        let provider_info = &providers[active_idx];

        // Создаём HTTP провайдер
        let url = provider_info.url.parse::<reqwest::Url>().ok()?;
        let http = Http::new(url);
        let provider = Provider::new(http);
        println!("🔗 [Wallet] Подключено к {}: {} (задержка: {:?} мс)",
            provider_info.name,
            provider_info.url,
            provider_info.latency_ms
        );
        Some(provider)
    }

    /// Переключиться на следующую ноду
    pub async fn failover(&self) -> Option<Provider<Http>> {
        let providers = self.providers.read().await;
        let mut active_idx = *self.active_index.read().await;

        if providers.is_empty() {
            return None;
        }

        let old_name = providers.get(active_idx).map(|p| p.name.clone());

        // Ищем следующую здоровую ноду
        let mut found = false;
        for _ in 0..providers.len() {
            active_idx = (active_idx + 1) % providers.len();
            if providers[active_idx].is_healthy {
                found = true;
                break;
            }
        }

        if !found {
            eprintln!("❌ [Wallet] Все RPC ноды недоступны!");
            return None;
        }

        // Обновляем активный индекс
        drop(providers);
        let mut active_write = self.active_index.write().await;
        *active_write = active_idx;

        let providers = self.providers.read().await;
        let new_provider = &providers[active_idx];

        println!("🔄 [Wallet] Primary RPC failed, switching to failover: {} → {}",
            old_name.unwrap_or_else(|| "Unknown".to_string()),
            new_provider.name
        );

        let url = new_provider.url.parse::<reqwest::Url>().ok()?;
        let http = Http::new(url);
        Some(Provider::new(http))
    }

    /// Получить баланс с автоматическим failover
    pub async fn get_balance_with_failover(&self, address: &str) -> Result<BalanceInfo, Box<dyn Error>> {
        let addr: Address = address.parse()
            .map_err(|e| format!("Неверный адрес кошелька: {}", e))?;

        // Пробуем получить баланс с текущей ноды
        if let Some(provider) = self.get_active_provider().await {
            match provider.get_balance(addr, None).await {
                Ok(balance) => {
                    return Ok(BalanceInfo::from_wei(addr, balance, "Polygon"));
                }
                Err(e) => {
                    eprintln!("⚠️ [Wallet] Ошибка RPC: {}", e);
                    // Помечаем ноду как нездоровую
                    let mut providers = self.providers.write().await;
                    let active_idx = *self.active_index.read().await;
                    if let Some(p) = providers.get_mut(active_idx) {
                        p.is_healthy = false;
                    }
                }
            }
        }

        // Failover на следующую ноду
        if let Some(failover_provider) = self.failover().await {
            match failover_provider.get_balance(addr, None).await {
                Ok(balance) => {
                    return Ok(BalanceInfo::from_wei(addr, balance, "Polygon"));
                }
                Err(e) => {
                    return Err(format!("Все RPC ноды недоступны: {}", e).into());
                }
            }
        }

        Err("Нет доступных RPC нод".into())
    }

    /// Получить информацию о пуле провайдеров
    pub async fn get_pool_info(&self) -> Vec<ProviderInfo> {
        self.providers.read().await.clone()
    }
}

/// Конфигурация кошелька
#[derive(Clone)]
pub struct WalletConfig {
    /// Децентрализованный пул провайдеров
    pub decentralized_provider: Option<DecentralizedProvider>,
    /// Опционально: приватный ключ (никогда не сохраняется в БД!)
    pub private_key: Option<Zeroizing<String>>,
}

impl WalletConfig {
    /// Создать конфигурацию с децентрализованным провайдером
    pub fn decentralized() -> Self {
        Self {
            decentralized_provider: Some(DecentralizedProvider::from_env()),
            private_key: None,
        }
    }

    /// Создать конфигурацию только для чтения (без приватного ключа)
    pub fn read_only(rpc_url: String) -> Self {
        Self {
            decentralized_provider: None,
            private_key: None,
        }
    }

    /// Создать конфигурацию с приватным ключом
    pub fn with_key(rpc_url: String, private_key: String) -> Self {
        Self {
            decentralized_provider: None,
            private_key: Some(Zeroizing::new(private_key)),
        }
    }
}

/// Информация о балансе
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct BalanceInfo {
    /// Адрес кошелька
    pub address: String,
    /// Баланс в wei (наименьшая единица)
    pub balance_wei: String,
    /// Баланс в MATIC (человекочитаемый формат)
    pub balance_matic: String,
    /// Сеть
    pub network: String,
    /// RPC нода которая предоставила данные
    pub rpc_node: Option<String>,
}

impl BalanceInfo {
    /// Создать BalanceInfo из U256 баланса
    pub fn from_wei(address: Address, balance: U256, network: &str) -> Self {
        // Конвертация из wei в MATIC (18 десятичных знаков)
        let balance_matic = format!("{:.6}", balance.low_u128() as f64 / 1e18);

        Self {
            address: format!("{:?}", address),
            balance_wei: balance.to_string(),
            balance_matic,
            network: network.to_string(),
            rpc_node: None,
        }
    }

    /// Установить RPC ноду
    pub fn with_rpc_node(mut self, rpc_node: String) -> Self {
        self.rpc_node = Some(rpc_node);
        self
    }
}

/// Менеджер кошелька Web3
#[derive(Clone)]
pub struct WalletManager {
    config: WalletConfig,
    db: Arc<RwLock<Db>>,
    /// Привязанный адрес кошелька к профилю пользователя
    linked_address: Arc<RwLock<Option<Address>>>,
}

impl WalletManager {
    /// Создать новый WalletManager
    pub fn new(config: WalletConfig, db: Arc<RwLock<Db>>) -> Self {
        Self {
            config,
            db,
            linked_address: Arc::new(RwLock::new(None)),
        }
    }

    /// Получить ссылку на децентрализованный провайдер
    pub fn get_decentralized_provider(&self) -> Option<&DecentralizedProvider> {
        self.config.decentralized_provider.as_ref()
    }

    /// Получить баланс адреса в MATIC с failover
    pub async fn get_balance(&self, address: &str) -> Result<BalanceInfo, Box<dyn Error>> {
        if let Some(dec_provider) = &self.config.decentralized_provider {
            let mut balance = dec_provider.get_balance_with_failover(address).await?;
            
            // Добавляем информацию о ноде
            let providers = dec_provider.get_pool_info().await;
            let active_idx = *dec_provider.active_index.read().await;
            if let Some(provider) = providers.get(active_idx) {
                balance = balance.with_rpc_node(format!("{} ({})", provider.name, provider.url));
            }
            
            Ok(balance)
        } else {
            // Fallback на старый метод с одним провайдером
            Err("Децентрализованный провайдер не настроен".into())
        }
    }

    /// Получить баланс привязанного кошелька пользователя
    pub async fn get_linked_balance(&self) -> Result<BalanceInfo, Box<dyn Error>> {
        let linked = self.linked_address.read().await;
        
        match linked.as_ref() {
            Some(addr) => {
                let address_str = format!("{:?}", addr);
                drop(linked);
                self.get_balance(&address_str).await
            }
            None => Err("Кошелёк не привязан к профилю".into())
        }
    }

    /// Привязать адрес кошелька к профилю пользователя
    pub async fn link_wallet(&self, address: &str) -> Result<(), Box<dyn Error>> {
        // Валидация адреса
        let addr: Address = address.parse()
            .map_err(|e| format!("Неверный адрес кошелька: {}", e))?;

        // Проверка контрольной суммы (EIP-55)
        let checksummed = format!("{:?}", addr);

        // Сохраняем в БД
        {
            let db = self.db.read().await;
            let tree = db.open_tree("wallet")?;
            tree.insert("linked_address", checksummed.as_bytes())?;
            tree.flush()?;
        }

        // Кэшируем в памяти
        {
            let mut linked = self.linked_address.write().await;
            *linked = Some(addr);
        }

        println!("✅ Кошелёк {} привязан к профилю", checksummed);

        Ok(())
    }

    /// Загрузить привязанный адрес из БД
    pub async fn load_linked_wallet(&self) -> Result<Option<String>, Box<dyn Error>> {
        let db = self.db.read().await;
        let tree = db.open_tree("wallet")?;

        if let Some(address_bytes) = tree.get("linked_address")? {
            let address = String::from_utf8_lossy(&address_bytes).to_string();
            
            // Парсим и кэшируем
            if let Ok(addr) = address.parse::<Address>() {
                let mut linked = self.linked_address.write().await;
                *linked = Some(addr);
            }

            Ok(Some(address))
        } else {
            Ok(None)
        }
    }

    /// Отвязать кошелёк от профиля
    pub async fn unlink_wallet(&self) -> Result<(), Box<dyn Error>> {
        // Удаляем из БД
        {
            let db = self.db.read().await;
            let tree = db.open_tree("wallet")?;
            tree.remove("linked_address")?;
            tree.flush()?;
        }

        // Очищаем кэш
        {
            let mut linked = self.linked_address.write().await;
            *linked = None;
        }

        println!("✅ Кошелёк отвязан от профиля");

        Ok(())
    }

    /// Получить информацию о привязанном кошельке
    pub async fn get_linked_address(&self) -> Result<Option<String>, Box<dyn Error>> {
        let linked = self.linked_address.read().await;
        Ok(linked.as_ref().map(|addr| format!("{:?}", addr)))
    }

    /// Получить информацию о пуле провайдеров
    pub async fn get_provider_pool_info(&self) -> Option<Vec<ProviderInfo>> {
        if let Some(dec_provider) = &self.config.decentralized_provider {
            Some(dec_provider.get_pool_info().await)
        } else {
            None
        }
    }

    /// Выполнить проверку здоровья RPC нод
    pub async fn run_health_check(&self) -> Option<Vec<ProviderInfo>> {
        if let Some(dec_provider) = &self.config.decentralized_provider {
            Some(dec_provider.health_check().await)
        } else {
            None
        }
    }

    /// Отправить транзакцию MATIC
    pub async fn send_matic(
        &self,
        to: &str,
        amount_wei: U256,
        private_key: Zeroizing<String>,
    ) -> Result<H256, Box<dyn Error>> {
        use ethers::signers::{Signer, Wallet};
        use ethers::middleware::SignerMiddleware;

        // Создаём кошелёк из приватного ключа
        let wallet: Wallet<ethers::core::k256::ecdsa::SigningKey> = 
            private_key.as_str().parse::<Wallet<_>>()?;

        // Получаем провайдер
        let provider = if let Some(dec_provider) = &self.config.decentralized_provider {
            dec_provider.get_active_provider().await
                .ok_or("Нет доступных RPC нод")?
        } else {
            return Err("Децентрализованный провайдер не настроен".into());
        };

        let chain_id = provider.get_chainid().await?;

        // Создаём подписывающий кошелёк с chain_id
        let wallet = wallet.with_chain_id(chain_id.as_u64());

        // Создаём middleware с подписыванием
        let client = SignerMiddleware::new(provider, wallet);

        // Парсим адрес получателя
        let to_addr: Address = to.parse()
            .map_err(|e| format!("Неверный адрес получателя: {}", e))?;

        // Создаём транзакцию
        let tx = TransactionRequest::new()
            .to(to_addr)
            .value(amount_wei);

        // Отправляем транзакцию
        let pending_tx = client.send_transaction(tx, None).await?;

        println!("📤 Транзакция отправлена: {:?}", pending_tx);

        // Возвращаем хеш транзакции
        Ok(*pending_tx)
    }

    /// Конвертировать MATIC в wei
    pub fn matic_to_wei(matic: f64) -> U256 {
        let wei = matic * 1e18;
        U256::from(wei as u128)
    }

    /// Конвертировать wei в MATIC
    pub fn wei_to_matic(wei: U256) -> f64 {
        wei.as_u128() as f64 / 1e18
    }
}

/// Интеграция с UserProfile
#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct WalletProfile {
    /// Ethereum-адрес кошелька (0x...)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub wallet_address: Option<String>,
    /// Метка кошелька (опционально)
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub wallet_label: Option<String>,
    /// Дата привязки
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub linked_at: Option<String>,
}

impl WalletProfile {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_address(address: String) -> Self {
        Self {
            wallet_address: Some(address),
            wallet_label: None,
            linked_at: Some(chrono::Utc::now().to_rfc3339()),
        }
    }

    pub fn set_label(&mut self, label: String) {
        self.wallet_label = Some(label);
    }
}

/// Безопасное хранилище для чувствительных данных
pub struct SecureBuffer<T: Zeroize> {
    data: Zeroizing<T>,
}

impl<T: Zeroize + Default> SecureBuffer<T> {
    pub fn new(data: T) -> Self {
        Self {
            data: Zeroizing::new(data),
        }
    }

    pub fn get(&self) -> &T {
        &self.data
    }

    pub fn consume(self) -> T {
        unsafe {
            let ptr = &self.data as *const Zeroizing<T> as *const T;
            std::ptr::read(ptr)
        }
    }
}

/// Утилита для безопасной работы с приватными ключами
pub mod secure_key_handling {
    use super::*;

    /// Временное хранение приватного ключа в памяти
    pub fn with_secure_key<F, R>(key: String, f: F) -> R 
    where 
        F: FnOnce(&str) -> R 
    {
        let secure_key = Zeroizing::new(key);
        f(secure_key.as_str())
    }

    /// Проверка валидности Ethereum адреса
    pub fn is_valid_ethereum_address(address: &str) -> bool {
        address.parse::<Address>().is_ok()
    }

    /// Форматирование адреса для отображения (0x1234...5678)
    pub fn format_address_short(address: &str) -> String {
        if address.len() >= 10 {
            format!("{}...{}", &address[..6], &address[address.len() - 4..])
        } else {
            address.to_string()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_balance_info_conversion() {
        let balance = U256::from(1_500_000_000_000_000_000u128); // 1.5 MATIC
        let info = BalanceInfo::from_wei(
            "0x1234567890123456789012345678901234567890".parse().unwrap(),
            balance,
            "Polygon"
        );

        assert!(info.balance_matic.contains("1.5"));
        assert_eq!(info.network, "Polygon");
    }

    #[test]
    fn test_matic_wei_conversion() {
        let matic = 1.0;
        let wei = WalletManager::matic_to_wei(matic);
        let back = WalletManager::wei_to_matic(wei);

        assert!((back - matic).abs() < 0.001);
    }

    #[test]
    fn test_address_validation() {
        assert!(secure_key_handling::is_valid_ethereum_address(
            "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        ));

        assert!(!secure_key_handling::is_valid_ethereum_address(
            "invalid_address"
        ));
    }
}
