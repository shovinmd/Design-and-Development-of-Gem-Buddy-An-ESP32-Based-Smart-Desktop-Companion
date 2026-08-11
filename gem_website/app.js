/* ==========================================================================
   GEM Buddy Showcase Website - Interaction Script
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
    // 1. Mobile Menu Toggle
    const menuToggle = document.getElementById('menu-toggle');
    const mainNav = document.getElementById('main-nav');
    const navLinks = document.querySelectorAll('.nav-link, .nav-btn');

    if (menuToggle && mainNav) {
        menuToggle.addEventListener('click', () => {
            menuToggle.classList.toggle('open');
            mainNav.classList.toggle('open');
        });

        // Close menu when clicking navigation links
        navLinks.forEach(link => {
            link.addEventListener('click', () => {
                menuToggle.classList.remove('open');
                mainNav.classList.remove('open');
            });
        });
    }

    // 2. Interactive Device Simulator
    const faceImg = document.getElementById('device-face-img');
    const sleepOverlay = document.getElementById('sleep-overlay');
    const guardOverlay = document.getElementById('guard-overlay');
    const statusText = document.getElementById('simulator-status-text');
    const ldrFill = document.getElementById('sim-ldr-fill');
    const ldrVal = document.getElementById('sim-ldr-val');
    const ctrlButtons = document.querySelectorAll('.ctrl-btn');

    // Simulator states config
    const states = {
        happy: {
            img: 'assets/images/gem_happy.jpg',
            status: 'GEM is happy, connected to WiFi, and tracking ambient desk light.',
            ldr: 65,
            showSleep: false,
            showGuard: false
        },
        sleep: {
            img: 'assets/images/gem_sleep.jpg',
            status: 'GEM is sleeping. Auto-dimmed display active. Standing by for touch waking.',
            ldr: 12,
            showSleep: false,
            showGuard: false
        },
        guard: {
            img: 'assets/images/gem_angry.jpg',
            status: 'Desk Guard Mode active. Webhooks primed to alert on touch or light changes.',
            ldr: 48,
            showSleep: false,
            showGuard: true
        }
    };

    ctrlButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const face = btn.getAttribute('data-face');
            const state = states[face];

            if (!state) return;

            // Update active button styling
            ctrlButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            // Apply updates to mock hardware device
            faceImg.src = state.img;
            statusText.textContent = state.status;
            
            // LDR Telemetry bar update
            ldrFill.style.width = `${state.ldr}%`;
            ldrVal.textContent = `${state.ldr}%`;

            // Sleep overlay display
            if (state.showSleep) {
                sleepOverlay.style.display = 'block';
                faceImg.style.opacity = '0.15';
            } else {
                sleepOverlay.style.display = 'none';
                faceImg.style.opacity = '0.95';
            }

            // Guard overlay display
            if (state.showGuard) {
                guardOverlay.style.display = 'block';
            } else {
                guardOverlay.style.display = 'none';
            }
        });
    });

    // 3. Tutorial Video Player (Embed YouTube on Play Click)
    const playOverlay = document.getElementById('video-play-overlay');
    if (playOverlay) {
        playOverlay.addEventListener('click', () => {
            playOverlay.style.opacity = '0';
            setTimeout(() => {
                playOverlay.style.display = 'none';
            }, 350);

            const iframeWrapper = document.getElementById('player-iframe-wrapper');
            if (iframeWrapper) {
                iframeWrapper.innerHTML = `<iframe src="https://www.youtube.com/embed/l00o5oz1m1Y?autoplay=1&rel=0" style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; border-radius: 20px;" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>`;
            }
        });
    }

    // 5. Trackpad feature card spotlight effect (ambient background hover follow)
    const cards = document.querySelectorAll('.feature-card');
    cards.forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = e.clientX - rect.left;
            const y = e.clientY - rect.top;
            card.style.setProperty('--x', `${x}px`);
            card.style.setProperty('--y', `${y}px`);
        });
    });

    // 6. Interactive mobile app showcase carousel
    const carouselTrack = document.getElementById('phone-carousel-track');
    const carouselViewport = document.querySelector('.phone-carousel-viewport');
    const prevBtn = document.getElementById('app-carousel-prev');
    const nextBtn = document.getElementById('app-carousel-next');
    const dotsContainer = document.getElementById('app-carousel-dots');
    const captionTitle = document.getElementById('carousel-slide-title');
    const captionDesc = document.getElementById('carousel-slide-desc');

    const appScreens = [
        {
            title: "1. Welcome & Onboarding",
            desc: "Meet your GEM companion app. Get a brief introduction to what your desktop assistant can do."
        },
        {
            title: "2. Wi-Fi Provisioning",
            desc: "Quickly set up your GEM device. Enter your Wi-Fi credentials to link your phone and the companion device."
        },
        {
            title: "3. Interactive Face Panel",
            desc: "Pet your GEM companion, customize eye styles, toggle features, and monitor your device status in real-time."
        },
        {
            title: "4. Device Controller",
            desc: "Turn the ambient lamp on/off, adjust light brightness, change LED modes, and set alarms."
        },
        {
            title: "5. Desk Guard Sentinel",
            desc: "Arm GEM to monitor your desk. Activate light trigger alerts, movement tracking, and physical touch alarms."
        },
        {
            title: "6. Incident Logs",
            desc: "View real-time security telemetry. Check logs, timestamps, and detail cards for past security alerts."
        },
        {
            title: "7. Over-the-Air Updates",
            desc: "Scan and wirelessly flash the latest firmware binary straight to your ESP32 device from your phone."
        },
        {
            title: "8. Preferences & Config",
            desc: "Configure timezone details, set custom nicknames, and toggle hardware parameters for your companion."
        },
        {
            title: "9. Integrated Help Guide",
            desc: "Access instructions, status LED keys, safety guidelines, and troubleshooting tips inside the app."
        }
    ];

    let currentSlideIndex = 0;
    let autoSlideInterval = null;

    if (carouselTrack) {
        // Generate dot elements
        appScreens.forEach((_, idx) => {
            const dot = document.createElement('div');
            dot.classList.add('carousel-dot');
            if (idx === 0) dot.classList.add('active');
            dot.addEventListener('click', () => {
                goToSlide(idx);
                resetAutoSlide();
            });
            dotsContainer.appendChild(dot);
        });

        const dots = document.querySelectorAll('.carousel-dot');

        function goToSlide(index) {
            currentSlideIndex = index;
            // Slide transition: shift track left relative to center-viewport anchor (left: 50%)
            carouselTrack.style.transform = `translateX(calc(-170px - ${currentSlideIndex * 340}px))`;
            
            // Update active, prev, and next classes on slides
            const slides = document.querySelectorAll('.phone-slide');
            slides.forEach((slide, idx) => {
                slide.classList.remove('active', 'prev-slide', 'next-slide');
                if (idx === currentSlideIndex) {
                    slide.classList.add('active');
                } else if (idx === currentSlideIndex - 1) {
                    slide.classList.add('prev-slide');
                } else if (idx === currentSlideIndex + 1) {
                    slide.classList.add('next-slide');
                }
            });
            
            // Update dots
            dots.forEach((dot, idx) => {
                if (idx === currentSlideIndex) {
                    dot.classList.add('active');
                } else {
                    dot.classList.remove('active');
                }
            });

            // Update captions
            if (captionTitle && captionDesc) {
                // Fade out caption slightly, change contents, fade back in
                captionTitle.style.opacity = 0;
                captionDesc.style.opacity = 0;
                setTimeout(() => {
                    captionTitle.textContent = appScreens[currentSlideIndex].title;
                    captionDesc.textContent = appScreens[currentSlideIndex].desc;
                    captionTitle.style.opacity = 1;
                    captionDesc.style.opacity = 1;
                }, 150);
            }
        }

        function nextSlide() {
            let nextIdx = (currentSlideIndex + 1) % appScreens.length;
            goToSlide(nextIdx);
        }

        function prevSlide() {
            let prevIdx = (currentSlideIndex - 1 + appScreens.length) % appScreens.length;
            goToSlide(prevIdx);
        }

        // Add button event listeners
        if (prevBtn) {
            prevBtn.addEventListener('click', () => {
                prevSlide();
                resetAutoSlide();
            });
        }
        if (nextBtn) {
            nextBtn.addEventListener('click', () => {
                nextSlide();
                resetAutoSlide();
            });
        }

        // Auto slide management
        function startAutoSlide() {
            autoSlideInterval = setInterval(nextSlide, 4500);
        }

        function resetAutoSlide() {
            clearInterval(autoSlideInterval);
            startAutoSlide();
        }

        // Gesture swipe/drag support (mouse & touch)
        let isDragging = false;
        let startX = 0;
        let currentX = 0;
        let diffX = 0;
        const swipeThreshold = 50; // pixels of movement required to trigger slide change

        const handleDragStart = (e) => {
            isDragging = true;
            startX = e.type === 'touchstart' ? e.touches[0].clientX : e.clientX;
            if (e.type === 'mousedown') {
                e.preventDefault();
            }
            clearInterval(autoSlideInterval);
        };

        const handleDragMove = (e) => {
            if (!isDragging) return;
            currentX = e.type === 'touchmove' ? e.touches[0].clientX : e.clientX;
            diffX = currentX - startX;
        };

        const handleDragEnd = () => {
            if (!isDragging) return;
            isDragging = false;
            
            if (Math.abs(diffX) > swipeThreshold) {
                if (diffX > 0) {
                    prevSlide();
                } else {
                    nextSlide();
                }
            }
            diffX = 0;
            resetAutoSlide();
        };

        if (carouselViewport) {
            // Touch events
            carouselViewport.addEventListener('touchstart', handleDragStart, { passive: true });
            carouselViewport.addEventListener('touchmove', handleDragMove, { passive: true });
            carouselViewport.addEventListener('touchend', handleDragEnd);

            // Mouse events
            carouselViewport.addEventListener('mousedown', handleDragStart);
            document.addEventListener('mousemove', handleDragMove);
            document.addEventListener('mouseup', handleDragEnd);
        }

        // Initialize transition effects on captions
        if (captionTitle && captionDesc) {
            captionTitle.style.transition = 'opacity 0.25s ease';
            captionDesc.style.transition = 'opacity 0.25s ease';
        }

        goToSlide(0);
        startAutoSlide();
    }

    // 7. Custom APK Download Modal Prompt
    const downloadApkBtn = document.getElementById('download-apk-btn');
    const downloadModal = document.getElementById('download-modal');
    const closeModalBtn = document.getElementById('close-modal-btn');
    const modalCancelBtn = document.getElementById('modal-cancel-btn');
    const modalOkBtn = document.getElementById('modal-ok-btn');

    if (downloadApkBtn && downloadModal) {
        // Show modal when clicking download button
        downloadApkBtn.addEventListener('click', (e) => {
            e.preventDefault();
            downloadModal.classList.add('active');
        });

        // Hide modal helper
        const hideModal = () => {
            downloadModal.classList.remove('active');
        };

        // Close event listeners
        if (closeModalBtn) closeModalBtn.addEventListener('click', hideModal);
        if (modalCancelBtn) modalCancelBtn.addEventListener('click', hideModal);

        // Click outside modal card to close
        downloadModal.addEventListener('click', (e) => {
            if (e.target === downloadModal) {
                hideModal();
            }
        });

        // Confirm download when OK is clicked
        if (modalOkBtn) {
            modalOkBtn.addEventListener('click', () => {
                hideModal();
                // Programmatically trigger download
                const tempLink = document.createElement('a');
                tempLink.href = downloadApkBtn.href;
                tempLink.download = downloadApkBtn.getAttribute('download') || 'Gem v1.2.0.apk';
                document.body.appendChild(tempLink);
                tempLink.click();
                document.body.removeChild(tempLink);
            });
        }
    }
});
