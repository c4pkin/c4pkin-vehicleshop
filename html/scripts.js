let shopItems = [];
let cart = [];
let currentCategory = "all";
let currentStoreId = null;
let isShopVisible = false;

document.addEventListener('DOMContentLoaded', function() {
    const vehicleShop = document.getElementById('vehicle-shop');
    const storeName = document.getElementById('store-name');
    const vehiclesGrid = document.getElementById('vehicles-grid');
    const currentCategoryTitle = document.getElementById('current-category');
    const vehicleSearch = document.getElementById('vehicle-search');
    const cartButton = document.getElementById('cart-button');
    const cartCount = document.getElementById('cart-count');
    const closeShopButton = document.getElementById('close-shop');
    const cartModal = document.getElementById('cart-modal');
    const cartItems = document.getElementById('cart-items');
    const cartTotalAmount = document.getElementById('cart-total-amount');
    const closeCartButton = document.getElementById('close-cart');
    const checkoutButton = document.getElementById('checkout-button');
    const paymentModal = document.getElementById('payment-modal');
    const closePaymentButton = document.getElementById('close-payment');
    const bankPaymentButton = document.getElementById('bank-payment');

    vehicleShop.style.display = 'none';

    window.addEventListener('message', function(event) {
        const data = event.data;

        if (data.action === "open") {
            shopItems = data.items || [];
            currentStoreId = data.storeId;
            
            storeName.textContent = data.storeName || "Premium Deluxe Gallery";
            
            vehicleShop.style.display = 'flex';
            setTimeout(() => vehicleShop.classList.add('active'), 10);
            
            cart = [];
            updateCartCount();
            displayVehicles();
            
            isShopVisible = true;
            
            document.body.style.backgroundColor = 'rgba(0, 0, 0, 0.4)';
            
        } else if (data.action === "close") {
            closeShop();
            
        } else if (data.action === "updateStock") {
            const itemIndex = shopItems.findIndex(item => item.name === data.itemName);
            if (itemIndex !== -1) {
                shopItems[itemIndex].stock = data.newStock;
                displayVehicles();
                
                updateCartItemStock(data.itemName, data.newStock);
            }
        }
    });

    document.querySelectorAll('.category-item').forEach(category => {
        category.addEventListener('click', function() {
            const categoryValue = this.getAttribute('data-category');
            changeCategory(categoryValue);
        });
    });

    vehicleSearch.addEventListener('input', function() {
        displayVehicles();
    });

    cartButton.addEventListener('click', function() {
        showCartModal();
    });

    closeShopButton.addEventListener('click', function() {
        closeShop();
    });

    closeCartButton.addEventListener('click', function() {
        cartModal.classList.remove('active');
    });

    checkoutButton.addEventListener('click', function() {
        if (cart.length > 0) {
            cartModal.classList.remove('active');
            showPaymentModal();
        }
    });

    closePaymentButton.addEventListener('click', function() {
        paymentModal.classList.remove('active');
        showCartModal();
    });

    bankPaymentButton.addEventListener('click', function() {
        processPayment('bank');
    });

    document.addEventListener('keydown', function(event) {
        if (event.key === "Escape" && isShopVisible) {
            if (paymentModal.classList.contains('active')) {
                paymentModal.classList.remove('active');
                return;
            }
            
            if (cartModal.classList.contains('active')) {
                cartModal.classList.remove('active');
                return;
            }
            
            closeShop();
        }
    });

    window.addEventListener('click', function(event) {
        if (event.target === cartModal) {
            cartModal.classList.remove('active');
        }
        
        if (event.target === paymentModal) {
            paymentModal.classList.remove('active');
        }
    });

    function enableMouseWheelScrolling() {
        const vehiclesGrid = document.getElementById('vehicles-grid');    
       
        vehiclesGrid.addEventListener('wheel', function(event) {

            event.preventDefault();
            
            const scrollAmount = event.deltaY * 0.5;
            
            vehiclesGrid.scrollTop += scrollAmount;
        });
    }

    function displayVehicles() {
        const searchTerm = vehicleSearch.value.toLowerCase();
        
        const filteredVehicles = shopItems.filter(vehicle => {
            const matchesCategory = currentCategory === 'all' || vehicle.category === currentCategory;
            const matchesSearch = vehicle.label.toLowerCase().includes(searchTerm);
            return matchesCategory && matchesSearch;
        });

        vehiclesGrid.innerHTML = '';

        if (filteredVehicles.length === 0) {
            const emptyMessage = document.createElement('div');
            emptyMessage.className = 'empty-message';
            emptyMessage.innerHTML = `
                <i class="fas fa-car-crash"></i>
                <p>Bu kriterlere uygun araç bulunamadı.</p>
            `;
            vehiclesGrid.appendChild(emptyMessage);
            return;
        }

        filteredVehicles.forEach(vehicle => {
            const isInCart = cart.some(item => item.name === vehicle.name);
            
            const vehicleCard = document.createElement('div');
            vehicleCard.className = 'vehicle-card animate-fade';
            vehicleCard.setAttribute('data-id', vehicle.name);
            
            let stockClass = '';
            let stockLabel = `Stok: ${vehicle.stock}`;
            
            if (vehicle.stock === 0) {
                stockClass = 'no-stock';
                stockLabel = 'Stokta yok';
            } else if (vehicle.stock < 3) {
                stockClass = 'low-stock';
            }
            
            vehicleCard.innerHTML = `
                <div class="vehicle-image" style="background-image: url('imgs/${vehicle.image || 'default.jpg'}')">
                    <div class="vehicle-stock ${stockClass}">${stockLabel}</div>
                </div>
                <div class="vehicle-info">
                    <div class="vehicle-title">
                        <span class="vehicle-name">${vehicle.label}</span>
                        <span class="vehicle-price">${vehicle.price.toLocaleString()} ₺</span>
                    </div>
                    <span class="vehicle-category">${vehicle.category.toUpperCase()}</span>
                    
                    ${vehicle.stock > 0 ? `
                        <div class="vehicle-actions">
                            ${isInCart ? `
                                <button class="btn-remove-cart">
                                    <i class="fas fa-times"></i>
                                    Sipariş Listesinden Çıkar
                                </button>
                            ` : `
                                <button class="btn-add-cart">
                                    <i class="fas fa-cart-plus"></i>
                                    Sipariş Et
                                </button>
                            `}
                        </div>
                    ` : `
                        <div class="vehicle-actions">
                            <span class="out-of-stock">Stokta Yok</span>
                        </div>
                    `}
                </div>
            `;
            
            vehiclesGrid.appendChild(vehicleCard);

            if (vehicle.stock > 0) {
                if (isInCart) {
                    const removeCartBtn = vehicleCard.querySelector('.btn-remove-cart');
                    
                    removeCartBtn.addEventListener('click', function() {
                        const cartItemIndex = cart.findIndex(item => item.name === vehicle.name);
                        if (cartItemIndex !== -1) {
                            cart.splice(cartItemIndex, 1);
                            updateCartCount();
                            displayVehicles();
                        }
                    });
                } else {
                    const addCartBtn = vehicleCard.querySelector('.btn-add-cart');
                    
                    addCartBtn.addEventListener('click', function() {
                        addToCart(vehicle, 1);
                        displayVehicles();
                    });
                }
            }
        });

        enableMouseWheelScrolling();
    }

    function changeCategory(category) {
        currentCategory = category;
        
        document.querySelectorAll('.category-item').forEach(item => {
            item.classList.remove('active');
        });
        
        document.querySelector(`.category-item[data-category="${category}"]`).classList.add('active');
        
        const categoryTitle = document.querySelector(`.category-item[data-category="${category}"]`).querySelector('span').textContent;
        currentCategoryTitle.textContent = categoryTitle;
        
        displayVehicles();
    }

    function addToCart(vehicle, quantity) {

        const existingCartItem = cart.find(item => item.name === vehicle.name);
        
        if (!existingCartItem) {
            cart.push({
                name: vehicle.name,
                label: vehicle.label,
                price: vehicle.price,
                quantity: 1, 
                image: vehicle.image || 'default.jpg'
            });
            
            updateCartCount();
        }
    }

    function updateCartItemStock(vehicleName, newStock) {
        const cartItem = cart.find(item => item.name === vehicleName);
        
        if (cartItem) {
            if (newStock <= 0) {

                const cartItemIndex = cart.findIndex(item => item.name === vehicleName);
                if (cartItemIndex !== -1) {
                    cart.splice(cartItemIndex, 1);
                    updateCartCount();
                }
            }
        }
    }

    function updateCartCount() {
        const totalItems = cart.length; 
        cartCount.textContent = totalItems;
    }

    function showCartModal() {
        displayCartItems();
        cartModal.classList.add('active');
    }

    function displayCartItems() {
        if (cart.length === 0) {
            cartItems.innerHTML = `
                <div class="cart-empty">
                    <i class="fas fa-shopping-cart"></i>
                    <p>Sipariş listeniz boş</p>
                </div>
            `;
            cartTotalAmount.textContent = '0 ₺';
            return;
        }
        
        let cartHTML = '';
        let total = 0;
        
        cart.forEach(item => {
            const itemTotal = item.price; 
            total += itemTotal;
            
            cartHTML += `
                <div class="cart-item" data-id="${item.name}">
                    <div class="cart-item-image" style="background-image: url('imgs/${item.image}')"></div>
                    <div class="cart-item-details">
                        <div class="cart-item-info">
                            <h4>${item.label}</h4>
                            <p class="cart-item-price">${item.price.toLocaleString()} ₺</p>
                        </div>
                        <div class="cart-item-actions">
                            <div class="cart-item-total">${itemTotal.toLocaleString()} ₺</div>
                            <button class="remove-item">
                                <i class="fas fa-trash-alt"></i>
                            </button>
                        </div>
                    </div>
                </div>
            `;
        });
        
        cartItems.innerHTML = cartHTML;
        cartTotalAmount.textContent = `${total.toLocaleString()} ₺`;
        
        document.querySelectorAll('.cart-item').forEach(cartItem => {
            const vehicleName = cartItem.getAttribute('data-id');
            const removeBtn = cartItem.querySelector('.remove-item');
            
            removeBtn.addEventListener('click', function() {
                const cartItemIndex = cart.findIndex(item => item.name === vehicleName);
                if (cartItemIndex !== -1) {
                    cart.splice(cartItemIndex, 1);
                    updateCartCount();
                    displayCartItems();
                    displayVehicles();
                }
            });
        });
    }

    function showPaymentModal() {
        paymentModal.classList.add('active');
    }

    function processPayment(method) {
        showNotification('Ödeme işlemi başarılı! Araçlarınız hazırlanıyor...', 'success');
        
        cart.forEach(item => {
            $.post('https://c4pkin-vehicleshop/BuyItem', JSON.stringify({
                item: shopItems.find(shopItem => shopItem.name === item.name),
                amount: 1 
            }), function(response) {
                if (response === 'ok') {
                    console.log('Araç satın alındı: ' + item.name);
                }
            });
        });

        cart = [];
        updateCartCount();
        
        paymentModal.classList.remove('active');
        
        setTimeout(function() {
            closeShop();
        }, 1500);
    }

    function closeShop() {
        SetNuiFocus(false, false);
        
        vehicleShop.classList.remove('active');
        setTimeout(() => {
            vehicleShop.style.display = 'none';
            document.body.style.backgroundColor = 'transparent';
        }, 300);
        
        cartModal.classList.remove('active');
        paymentModal.classList.remove('active');
        
        isShopVisible = false;
        
        $.post('https://c4pkin-vehicleshop/CloseShop', JSON.stringify({}));
    }

    function SetNuiFocus(focus, cursor) {
        $.post('https://c4pkin-vehicleshop/SetNuiFocus', JSON.stringify({
            focus: focus,
            cursor: cursor
        }));
    }

    function showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = `notification ${type}`;
        notification.innerHTML = `
            <i class="fas ${type === 'success' ? 'fa-check-circle' : 'fa-info-circle'}"></i>
            <span>${message}</span>
        `;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.classList.add('show');
        }, 10);
        
        setTimeout(() => {
            notification.classList.remove('show');
            setTimeout(() => {
                notification.remove();
            }, 300);
        }, 3000);
    }
});