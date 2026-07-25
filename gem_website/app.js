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

    // 3. Tutorial Video Player Mockup Simulation
    const playOverlay = document.getElementById('video-play-overlay');
    const timelinePlayed = document.querySelector('.timeline-played');
    const timelineHandle = document.querySelector('.timeline-handle');
    const timeLabel = document.querySelector('.time-label');
    const playButtonAction = document.getElementById('play-button-action');

    let videoInterval = null;

    const startMockVideoTimeline = () => {
        if (videoInterval) clearInterval(videoInterval);
        
        let percentage = 40;
        let seconds = 134; // 2:14 out of 5:40 (340 seconds total)
        const totalSeconds = 340;

        videoInterval = setInterval(() => {
            seconds++;
            if (seconds >= totalSeconds) {
                seconds = 0;
            }
            percentage = (seconds / totalSeconds) * 100;
            
            // Update UI elements
            if (timelinePlayed) timelinePlayed.style.width = `${percentage}%`;
            if (timelineHandle) timelineHandle.style.left = `${percentage}%`;
            
            const curMin = Math.floor(seconds / 60);
            const curSec = Math.floor(seconds % 60).toString().padStart(2, '0');
            const totMin = Math.floor(totalSeconds / 60);
            const totSec = Math.floor(totalSeconds % 60).toString().padStart(2, '0');
            
            if (timeLabel) {
                timeLabel.textContent = `${curMin}:${curSec} / ${totMin}:${totSec}`;
            }
        }, 1000);
    };

    if (playOverlay) {
        // Support overlay click to trigger mock video playing
        playOverlay.addEventListener('click', () => {
            playOverlay.style.opacity = '0';
            setTimeout(() => {
                playOverlay.style.display = 'none';
            }, 350);

            // Change loader text to streaming status
            const loadingText = document.querySelector('.video-loading-text');
            if (loadingText) {
                loadingText.textContent = 'Streaming Setup Walkthrough... (YouTube Video Placeholder)';
            }
            
            const spinner = document.querySelector('.spinner');
            if (spinner) {
                spinner.style.borderTopColor = '#10b981'; // Green active playing state spinner
            }

            // Animate timeline
            startMockVideoTimeline();
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
    const carouselTrack = document.getElementById('phone-slideshow');
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
            desc: "Turn the ambient lamp on/off, adjust light brightness, change LED modes, and configure sleep timers."
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
            // Slide transition
            carouselTrack.style.transform = `translateX(-${currentSlideIndex * 100}%)`;
            
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

        // Initialize transition effects on captions
        if (captionTitle && captionDesc) {
            captionTitle.style.transition = 'opacity 0.25s ease';
            captionDesc.style.transition = 'opacity 0.25s ease';
        }

        startAutoSlide();
    }
});
