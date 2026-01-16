/**
 * Multi-location Looking Glass - Custom UI Script
 * 
 * This script injects:
 * 1. A navigation bar at the top for switching between locations
 * 2. A Speed Test section with download links
 * 
 * Configuration is loaded from window.LOOKING_GLASS_CONFIG or defaults
 */

(function() {
  'use strict';

  // ==========================================================================
  // Configuration - Override these values or set window.LOOKING_GLASS_CONFIG
  // ==========================================================================
  const DEFAULT_CONFIG = {
    // Current location identifier
    currentLocation: 'default',
    
    // Available locations for the navigation bar
    locations: [
      {
        id: 'moscow',
        name: 'Moscow, RU',
        url: 'https://lg-moscow.example.com',
        flag: '🇷🇺'
      },
      {
        id: 'amsterdam',
        name: 'Amsterdam, NL',
        url: 'https://lg-amsterdam.example.com',
        flag: '🇳🇱'
      },
      {
        id: 'frankfurt',
        name: 'Frankfurt, DE',
        url: 'https://lg-frankfurt.example.com',
        flag: '🇩🇪'
      }
    ],
    
    // Speed test configuration
    speedTest: {
      enabled: true,
      title: 'Speed Test Downloads',
      description: 'Download test files to measure network performance',
      // Base URL for speed test files (nginx serves these)
      baseUrl: '/speedtest',
      files: [
        { name: '10 MB', file: '10MB.bin', size: '10 MB' },
        { name: '100 MB', file: '100MB.bin', size: '100 MB' },
        { name: '1 GB', file: '1GB.bin', size: '1 GB' }
      ]
    },
    
    // Styling options
    theme: {
      navBarBg: '#1a202c',           // Dark background
      navBarBgLight: '#ffffff',       // Light mode background
      navBarText: '#ffffff',          // Dark mode text
      navBarTextLight: '#1a202c',     // Light mode text
      accentColor: '#3182ce',         // Blue accent (Chakra blue.500)
      speedTestBg: '#2d3748',         // Speed test section bg (dark)
      speedTestBgLight: '#edf2f7'     // Speed test section bg (light)
    }
  };

  // Merge with global config if available
  const CONFIG = window.LOOKING_GLASS_CONFIG 
    ? { ...DEFAULT_CONFIG, ...window.LOOKING_GLASS_CONFIG }
    : DEFAULT_CONFIG;

  // ==========================================================================
  // Utility Functions
  // ==========================================================================

  /**
   * Detect current color mode from Chakra UI
   */
  function getColorMode() {
    const body = document.body;
    const chakraColorMode = body.classList.contains('chakra-ui-dark') ? 'dark' : 'light';
    const localStorageMode = localStorage.getItem('chakra-ui-color-mode');
    return localStorageMode || chakraColorMode;
  }

  /**
   * Create an element with attributes and children
   */
  function createElement(tag, attrs = {}, children = []) {
    const el = document.createElement(tag);
    
    Object.entries(attrs).forEach(([key, value]) => {
      if (key === 'style' && typeof value === 'object') {
        Object.assign(el.style, value);
      } else if (key === 'className') {
        el.className = value;
      } else if (key.startsWith('on') && typeof value === 'function') {
        el.addEventListener(key.substring(2).toLowerCase(), value);
      } else {
        el.setAttribute(key, value);
      }
    });
    
    children.forEach(child => {
      if (typeof child === 'string') {
        el.appendChild(document.createTextNode(child));
      } else if (child) {
        el.appendChild(child);
      }
    });
    
    return el;
  }

  // ==========================================================================
  // Navigation Bar Component
  // ==========================================================================

  function createNavigationBar() {
    const isDark = getColorMode() === 'dark';
    const { theme, locations, currentLocation } = CONFIG;
    
    const navContainer = createElement('div', {
      id: 'lg-nav-container',
      style: {
        position: 'fixed',
        top: '0',
        left: '0',
        right: '0',
        zIndex: '9999',
        backgroundColor: isDark ? theme.navBarBg : theme.navBarBgLight,
        borderBottom: `1px solid ${isDark ? '#2d3748' : '#e2e8f0'}`,
        boxShadow: '0 1px 3px rgba(0,0,0,0.12)',
        transition: 'background-color 0.2s ease'
      }
    });

    const navInner = createElement('div', {
      style: {
        maxWidth: '1200px',
        margin: '0 auto',
        padding: '8px 16px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        flexWrap: 'wrap',
        gap: '8px'
      }
    });

    // Logo/Title section
    const logoSection = createElement('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: '8px'
      }
    }, [
      createElement('span', {
        style: {
          fontSize: '14px',
          fontWeight: '600',
          color: isDark ? theme.navBarText : theme.navBarTextLight
        }
      }, ['🌐 Network Locations:'])
    ]);

    // Locations buttons
    const locationsContainer = createElement('div', {
      style: {
        display: 'flex',
        alignItems: 'center',
        gap: '6px',
        flexWrap: 'wrap'
      }
    });

    locations.forEach(location => {
      const isActive = location.id === currentLocation;
      const btn = createElement('a', {
        href: location.url,
        style: {
          display: 'inline-flex',
          alignItems: 'center',
          gap: '4px',
          padding: '6px 12px',
          borderRadius: '6px',
          fontSize: '13px',
          fontWeight: isActive ? '600' : '400',
          textDecoration: 'none',
          color: isActive 
            ? '#ffffff' 
            : (isDark ? theme.navBarText : theme.navBarTextLight),
          backgroundColor: isActive 
            ? theme.accentColor 
            : 'transparent',
          border: `1px solid ${isActive ? theme.accentColor : (isDark ? '#4a5568' : '#cbd5e0')}`,
          cursor: isActive ? 'default' : 'pointer',
          transition: 'all 0.2s ease'
        }
      }, [
        createElement('span', {}, [location.flag || '📍']),
        createElement('span', {}, [location.name])
      ]);

      if (!isActive) {
        btn.addEventListener('mouseenter', () => {
          btn.style.backgroundColor = isDark ? '#2d3748' : '#edf2f7';
          btn.style.borderColor = theme.accentColor;
        });
        btn.addEventListener('mouseleave', () => {
          btn.style.backgroundColor = 'transparent';
          btn.style.borderColor = isDark ? '#4a5568' : '#cbd5e0';
        });
      }

      locationsContainer.appendChild(btn);
    });

    navInner.appendChild(logoSection);
    navInner.appendChild(locationsContainer);
    navContainer.appendChild(navInner);

    return navContainer;
  }

  // ==========================================================================
  // Speed Test Section Component
  // ==========================================================================

  function createSpeedTestSection() {
    if (!CONFIG.speedTest.enabled) return null;

    const isDark = getColorMode() === 'dark';
    const { theme, speedTest } = CONFIG;

    const container = createElement('div', {
      id: 'lg-speedtest-container',
      style: {
        margin: '24px auto',
        maxWidth: '800px',
        padding: '0 16px'
      }
    });

    const card = createElement('div', {
      style: {
        backgroundColor: isDark ? theme.speedTestBg : theme.speedTestBgLight,
        borderRadius: '12px',
        padding: '24px',
        border: `1px solid ${isDark ? '#4a5568' : '#e2e8f0'}`
      }
    });

    // Header
    const header = createElement('div', {
      style: {
        marginBottom: '16px'
      }
    }, [
      createElement('h3', {
        style: {
          fontSize: '18px',
          fontWeight: '600',
          color: isDark ? '#ffffff' : '#1a202c',
          marginBottom: '4px',
          display: 'flex',
          alignItems: 'center',
          gap: '8px'
        }
      }, [
        createElement('span', {}, ['⚡']),
        createElement('span', {}, [speedTest.title])
      ]),
      createElement('p', {
        style: {
          fontSize: '14px',
          color: isDark ? '#a0aec0' : '#718096'
        }
      }, [speedTest.description])
    ]);

    // Download buttons grid
    const buttonsGrid = createElement('div', {
      style: {
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))',
        gap: '12px'
      }
    });

    speedTest.files.forEach(fileInfo => {
      const downloadUrl = `${speedTest.baseUrl}/${fileInfo.file}`;
      
      const btn = createElement('a', {
        href: downloadUrl,
        download: fileInfo.file,
        style: {
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          padding: '16px',
          borderRadius: '8px',
          backgroundColor: theme.accentColor,
          color: '#ffffff',
          textDecoration: 'none',
          transition: 'all 0.2s ease',
          cursor: 'pointer'
        }
      }, [
        createElement('span', {
          style: {
            fontSize: '24px',
            marginBottom: '4px'
          }
        }, ['⬇️']),
        createElement('span', {
          style: {
            fontSize: '16px',
            fontWeight: '600'
          }
        }, [fileInfo.name]),
        createElement('span', {
          style: {
            fontSize: '12px',
            opacity: '0.8'
          }
        }, [fileInfo.size])
      ]);

      btn.addEventListener('mouseenter', () => {
        btn.style.transform = 'translateY(-2px)';
        btn.style.boxShadow = '0 4px 12px rgba(49, 130, 206, 0.4)';
      });
      btn.addEventListener('mouseleave', () => {
        btn.style.transform = 'translateY(0)';
        btn.style.boxShadow = 'none';
      });

      buttonsGrid.appendChild(btn);
    });

    card.appendChild(header);
    card.appendChild(buttonsGrid);
    container.appendChild(card);

    return container;
  }

  // ==========================================================================
  // Main Injection Logic
  // ==========================================================================

  function injectUI() {
    // Wait for the main app to be mounted
    const mainContent = document.querySelector('#__next') || document.body;

    // 1. Inject Navigation Bar
    const existingNav = document.getElementById('lg-nav-container');
    if (existingNav) {
      existingNav.remove();
    }
    
    const navBar = createNavigationBar();
    document.body.insertBefore(navBar, document.body.firstChild);

    // Add padding to body to account for fixed navbar
    document.body.style.paddingTop = '52px';

    // 2. Inject Speed Test Section
    // Find the main container and inject after the header/title
    const injectSpeedTest = () => {
      const existingSpeedTest = document.getElementById('lg-speedtest-container');
      if (existingSpeedTest) {
        existingSpeedTest.remove();
      }

      // Try to find a good injection point (after the query form)
      const queryForm = document.querySelector('form');
      const mainContainer = document.querySelector('main') || mainContent;
      
      const speedTestSection = createSpeedTestSection();
      if (speedTestSection) {
        if (queryForm && queryForm.parentNode) {
          // Insert after the form's parent container
          const formParent = queryForm.closest('[class*="Stack"]') || queryForm.parentNode;
          formParent.parentNode.insertBefore(speedTestSection, formParent.nextSibling);
        } else {
          // Fallback: append to main container
          mainContainer.appendChild(speedTestSection);
        }
      }
    };

    // Delay speed test injection to ensure React has mounted
    setTimeout(injectSpeedTest, 500);

    // Re-inject on color mode change
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.attributeName === 'class' || mutation.attributeName === 'data-theme') {
          // Rebuild components with new color mode
          const existingNav = document.getElementById('lg-nav-container');
          if (existingNav) {
            const newNav = createNavigationBar();
            existingNav.replaceWith(newNav);
          }

          const existingSpeedTest = document.getElementById('lg-speedtest-container');
          if (existingSpeedTest) {
            const newSpeedTest = createSpeedTestSection();
            if (newSpeedTest) {
              existingSpeedTest.replaceWith(newSpeedTest);
            }
          }
        }
      });
    });

    observer.observe(document.body, { attributes: true });
  }

  // ==========================================================================
  // Initialize on DOM Ready
  // ==========================================================================

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectUI);
  } else {
    // DOM already loaded, inject immediately
    injectUI();
  }

  // Also listen for React's hydration
  window.addEventListener('load', () => {
    setTimeout(injectUI, 100);
  });

})();
