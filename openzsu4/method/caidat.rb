module ZSU::Caidat
  HTML = <<~'HTML'
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <title>Plugin Settings</title>
    BASE_PLACEHOLDER
    <link rel="stylesheet" href="css/style.css">
    <script src="js/vue.min.js"></script>
</head>
<body>
<div id="settings-container">
    <div id="loading-overlay" class="loading-overlay">
        <div class="spinner"></div>
        <div class="loading-text">Đang tải cài đặt...</div>
    </div>
    <div id="tabs">
        <div class="search-box">
            <input type="text" id="search-input" placeholder="Tìm kiếm..." oninput="handleSearch(this.value)" spellcheck="false" autocomplete="off">
            <button class="search-clear" onclick="document.getElementById('search-input').value='';handleSearch('');" title="Xóa tìm kiếm">×</button>
        </div>
        <div class="tabs-list">
            <div class="tab active" data-tab="cai_dat"><img src="../icons/caidat.svg" class="tab-icon">Cài đặt</div>
            <div class="tab" data-tab="tao_van"><img src="../icons/taovan.svg" class="tab-icon">Tạo ván</div>
            <div class="tab" data-tab="tao_canh"><img src="../icons/taocanh.svg" class="tab-icon">Tạo cánh</div>
            <div class="tab" data-tab="duc_khung"><img src="../icons/duckhung.svg" class="tab-icon">Đục khung</div>
            <div class="tab" data-tab="ban_le"><img src="../icons/banle.svg" class="tab-icon">Bản lề</div>
            <div class="tab" data-tab="doday"><img src="../icons/doday.svg" class="tab-icon">Độ dày</div>
            <div class="tab" data-tab="phuc_hoi"><img src="../icons/phuchoi.svg" class="tab-icon">Phục hồi
            </div>
            <div class="tab" data-tab="bo_goc"><img src="../icons/bogoc.svg" class="tab-icon">Bo góc</div>
            <div class="tab" data-tab="bao_ranh"><img src="../icons/baoranh.svg" class="tab-icon">Bào rãnh</div>
            <div class="tab" data-tab="uon_cong"><img src="../icons/uoncong.svg" class="tab-icon">Uốn cong
            </div>
            <div class="tab" data-tab="mong_go"><img src="../icons/monggo.svg" class="tab-icon">Mộng gỗ
            </div>
            <div class="tab" data-tab="lien_ket"><img src="../icons/lienket.svg" class="tab-icon">Liên kết
            </div>
            <div class="tab" data-tab="am_duong"><img src="../icons/amduong.svg" class="tab-icon">Âm dương
            </div>
            <div class="tab" data-tab="khu_dao"><img src="../icons/khudao.svg" class="tab-icon">Khử dao</div>
            <div class="tab" data-tab="khau_van"><img src="../icons/khauvan.svg" class="tab-icon">Khấu ván</div>
            <div class="tab" data-tab="noi_van"><img src="../icons/noivan.svg" class="tab-icon">Nối ván</div>
        </div>
        <div class="tabs-footer" onclick="toggleSidebar()">
            <span class="tabs-footer-label">Thu gọn danh mục</span>
            <span class="tabs-footer-icon">‹</span>
        </div>
    </div>
    <div id="tab-content">
        <div class="tab-panel active" id="panel_cai_dat">
            <iframe id="iframe_cai_dat" data-tab="cai_dat" src="caidat.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_tao_van">
            <iframe id="iframe_tao_van" data-tab="tao_van" src="taovan.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_tao_canh">
            <iframe id="iframe_tao_canh" data-tab="tao_canh" src="taocanh.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_duc_khung">
            <iframe id="iframe_duc_khung" data-tab="duc_khung" src="duckhung.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_ban_le">
            <iframe id="iframe_ban_le" data-tab="ban_le" src="banle.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_doday">
            <iframe id="iframe_doday" data-tab="doday" src="doday.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_phuc_hoi">
            <iframe id="iframe_phuc_hoi" data-tab="phuc_hoi" src="phuchoi.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_bo_goc">
            <iframe id="iframe_bo_goc" data-tab="bo_goc" src="bogoc.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_uon_cong">
            <iframe id="iframe_uon_cong" data-tab="uon_cong" src="uoncong.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_mong_go">
            <iframe id="iframe_mong_go" data-tab="mong_go" src="monggo.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_lien_ket">
            <iframe id="iframe_lien_ket" data-tab="lien_ket" src="lienket.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_bao_ranh">
            <iframe id="iframe_bao_ranh" data-tab="bao_ranh" src="baoranh.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_am_duong">
            <iframe id="iframe_am_duong" data-tab="am_duong" src="amduong.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_khu_dao">
            <iframe id="iframe_khu_dao" data-tab="khu_dao" src="khudao.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_khau_van">
            <iframe id="iframe_khau_van" data-tab="khau_van" src="khauvan.html" frameborder="0"></iframe>
        </div>
        <div class="tab-panel" id="panel_noi_van">
            <iframe id="iframe_noi_van" data-tab="noi_van" src="noivan.html" frameborder="0"></iframe>
        </div>
    </div>
</div>
<script>
    const tabs = document.querySelectorAll('.tab');
    let currentTabId = 'cai_dat';
    let allSettings = {};
    let isSettingsLoaded = false;
    let hideUnavailable = true;
    var searchIndex = {};
    var searchQuery = '';
    let iframesReady = {};
    document.querySelectorAll('iframe').forEach(iframe => {
        const tabId = iframe.getAttribute('data-tab');
        if (tabId) iframesReady[tabId] = false;
    });
    let pendingLoads = new Set();
    function handleSearch(value) {
        searchQuery = value.trim().toLowerCase();
        tabs.forEach(function(tab) {
            var tabId = tab.getAttribute('data-tab');
            if (!searchQuery) {
                tab.classList.remove('search-hidden');
                return;
            }
            var tabName = tab.textContent.trim().toLowerCase();
            var items = searchIndex[tabId] || [];
            var match = tabName.includes(searchQuery) || items.some(function(item) {
                return item.toLowerCase().includes(searchQuery);
            });
            tab.classList.toggle('search-hidden', !match);
        });
        sendSearchHighlight(currentTabId, searchQuery);
    }
    function sendSearchHighlight(tabId, query) {
        var iframe = document.getElementById('iframe_' + tabId);
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({ action: 'search_highlight', query: query }, '*');
        }
    }
    function switchToTab(tabId) {
        var activeTab = document.querySelector('.tab.active');
        if (activeTab) activeTab.classList.remove('active');
        var activePanel = document.querySelector('.tab-panel.active');
        if (activePanel) activePanel.classList.remove('active');
        const tab = document.querySelector('.tab[data-tab="' + tabId + '"]');
        const panel = document.getElementById('panel_' + tabId);
        if (tab && panel) {
            tab.classList.add('active');
            panel.classList.add('active');
            if (isSettingsLoaded && iframesReady[tabId]) {
                loadSettingsToIframe(tabId);
            } else if (isSettingsLoaded) {
                pendingLoads.add(tabId);
            }
        }
        currentTabId = tabId;
        if (searchQuery) sendSearchHighlight(tabId, searchQuery);
    }
    window.selectPresetByName = function(name) {
        var iframe = document.getElementById('iframe_' + currentTabId);
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({ action: 'select_preset', name: name }, '*');
        }
    }
    function loadSettingsToIframe(tabId) {
        const iframeId = 'iframe_' + tabId;
        const iframe = document.getElementById(iframeId);
        if (!iframe || !iframe.contentWindow) {
            return;
        }
        const tabSettings = allSettings[tabId] || {};
        iframe.contentWindow.postMessage({
            action: 'loadSettings',
            settings: tabSettings,
            hideUnavailable: hideUnavailable,
            suVersion: allSettings.su_version
        }, '*');
    }
    function hideLoading() {
        const overlay = document.getElementById('loading-overlay');
        if (overlay) {
            overlay.style.display = 'none';
        }
    }
    tabs.forEach(function (tab) {
        tab.addEventListener('click', function () {
            const tabId = tab.getAttribute('data-tab');
            switchToTab(tabId);
        });
    });
    window.addEventListener('message', function (event) {
        if (event.data && event.data.action === 'iframe_ready') {
            const tabId = event.data.tabId;
            iframesReady[tabId] = true;
            var sidebarCollapsed = document.getElementById('tabs').classList.contains('collapsed');
            var iframe = document.getElementById('iframe_' + tabId);
            if (iframe && iframe.contentDocument) {
                if (sidebarCollapsed) {
                    var col3 = iframe.contentDocument.querySelector('.col3');
                    if (col3) col3.classList.add('expanded');
                }
                var currentTheme = document.documentElement.getAttribute('data-theme');
                if (currentTheme) {
                    iframe.contentDocument.documentElement.setAttribute('data-theme', currentTheme);
                }
            }
            if (isSettingsLoaded && (tabId === currentTabId || pendingLoads.has(tabId))) {
                setTimeout(function () {
                    loadSettingsToIframe(tabId);
                    pendingLoads.delete(tabId);
                }, 100);
            }
        } else if (event.data && event.data.action === 'search_index') {
            searchIndex[event.data.tabId] = event.data.items;
        } else if (event.data && event.data.action === 'export_settings') {
            if (window.sketchup) {
                window.sketchup.export_settings();
            } else {
                window.location.href = 'skp:export_settings';
            }
        } else if (event.data && event.data.action === 'import_settings') {
            if (window.sketchup) {
                window.sketchup.import_settings();
            } else {
                window.location.href = 'skp:import_settings';
            }
        } else if (event.data && event.data.action === 'reset_settings') {
            if (window.sketchup) {
                window.sketchup.reset_settings();
            } else {
                window.location.href = 'skp:reset_settings';
            }
        } else if (event.data && event.data.action === 'reset_section') {
            var sectionId = event.data.tabId;
            if (window.sketchup) {
                window.sketchup.reset_section(sectionId);
            } else {
                window.location.href = 'skp:reset_section@' + sectionId;
            }
        } else if (event.data && event.data.action === 'export_online') {
            if (window.sketchup) {
                window.sketchup.export_online();
            } else {
                window.location.href = 'skp:export_online';
            }
        } else if (event.data && event.data.action === 'import_online') {
            if (window.sketchup) {
                window.sketchup.import_online();
            } else {
                window.location.href = 'skp:import_online';
            }
        } else if (event.data && event.data.action === 'view_hardware_id') {
            if (window.sketchup) {
                window.sketchup.view_hardware_id();
            } else {
                window.location.href = 'skp:view_hardware_id';
            }
        } else if (event.data && event.data.action === 'deactivate_license') {
            if (window.sketchup) {
                window.sketchup.deactivate_license();
            } else {
                window.location.href = 'skp:deactivate_license';
            }
        } else if (event.data && event.data.action === 'check_update') {
            if (window.sketchup) {
                window.sketchup.check_update();
            } else {
                window.location.href = 'skp:reset_settings';
            }
        } else if (event.data && event.data.action === 'install_version') {
            if (window.sketchup) {
                window.sketchup.install_version(event.data.version);
            }
        } else if (event.data && event.data.action === 'check_update_version') {
            if (window.sketchup) {
                window.sketchup.check_update_version();
            }
        } else if (event.data && event.data.action === 'restore_from_backup') {
            if (window.sketchup) {
                window.sketchup.restore_from_backup();
            }
        } else if (event.data && event.data.action === 'uninstall') {
            if (window.sketchup) {
                window.sketchup.uninstall();
            }
        } else if (event.data && event.data.action === 'select_version') {
            if (window.sketchup) {
                window.sketchup.select_version();
            }
        } else if (event.data && event.data.action === 'select_icon_folder') {
            if (window.sketchup) {
                window.sketchup.select_icon_folder();
            }
        } else if (event.data && event.data.action === 'set_theme') {
        applyTheme(event.data.theme);
    } else if (event.data && event.data.action === 'save_setting') {
            const tabId = event.data.tabId || currentTabId;
            if (!allSettings[tabId]) {
                allSettings[tabId] = {};
            }
            allSettings[tabId][event.data.key] = event.data.value;
            const val = (typeof event.data.value === 'object') ? JSON.stringify(event.data.value) : event.data.value;
            if (window.sketchup) {
                const params = tabId + '@' + event.data.key + '@' + val;
                window.sketchup.save_setting(params);
            } else {
                window.location.href = 'skp:save_setting@' + tabId + '@' + event.data.key + '@' + val;
            }
        } else if (event.data && event.data.action === 'load_presets') {
            if (window.sketchup) {
                window.sketchup.load_presets(event.data.tabId, function (response) {
                    try {
                        const presets = JSON.parse(response);
                        sendPresetsToIframe(event.data.tabId, presets);
                    } catch (e) {
                        console.error('[Settings] Failed to parse presets:', e);
                    }
                });
            } else {
                window.location.href = 'skp:load_presets@' + event.data.tabId;
            }
        } else if (event.data && event.data.action === 'save_preset') {
            const settingsJson = JSON.stringify(event.data.settings);
            const params = event.data.tabId + '@' + event.data.presetName + '@' + settingsJson;
            if (window.sketchup) {
                window.sketchup.save_preset(params);
            } else {
                window.location.href = 'skp:save_preset@' + params;
            }
        } else if (event.data && event.data.action === 'load_preset') {
            const params = event.data.tabId + '@' + event.data.presetName;
            if (window.sketchup) {
                window.sketchup.load_preset(params);
            } else {
                window.location.href = 'skp:load_preset@' + params;
            }
        } else if (event.data && event.data.action === 'delete_preset') {
            const params = event.data.tabId + '@' + event.data.presetName;
            if (window.sketchup) {
                window.sketchup.delete_preset(params);
            } else {
                window.location.href = 'skp:delete_preset@' + params;
            }
        } else if (event.data && event.data.action === 'save_presets_order') {
            const presetsJson = JSON.stringify(event.data.presets);
            const params = event.data.tabId + '@' + presetsJson;
            if (window.sketchup) {
                window.sketchup.save_presets_order(params);
            } else {
                window.location.href = 'skp:save_presets_order@' + params;
            }
        } else if (event.data && event.data.action === 'save_collapsed_groups') {
            const groupsJson = JSON.stringify(event.data.collapsedGroups);
            const params = event.data.tabId + '@' + groupsJson;
            if (window.sketchup) {
                window.sketchup.save_collapsed_groups(params);
            } else {
                window.location.href = 'skp:save_collapsed_groups@' + params;
            }
        } else if (event.data && event.data.action === 'pick_file') {
            const params = event.data.tabId + '@' + event.data.shapeKey + '@' + event.data.pathKey;
            if (window.sketchup) {
                window.sketchup.pick_file(params);
            } else {
                window.location.href = 'skp:pick_file@' + params;
            }
        }
    });
    function sendPresetsToIframe(tabId, presets, collapsedGroups) {
        const iframeId = 'iframe_' + tabId;
        const iframe = document.getElementById(iframeId);
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({
                action: 'presets_loaded',
                presets: presets,
                collapsedGroups: collapsedGroups
            }, '*');
        }
    }
    function sendSettingsToIframe(tabId, settings) {
        const iframeId = 'iframe_' + tabId;
        const iframe = document.getElementById(iframeId);
        if (iframe && iframe.contentWindow) {
            iframe.contentWindow.postMessage({
                action: 'preset_settings_loaded',
                settings: settings
            }, '*');
        }
    }
    window.sendPresetsToIframe = sendPresetsToIframe;
    window.sendSettingsToIframe = sendSettingsToIframe;
    window.loadAllSettings = function (settingsData) {
        allSettings = settingsData;
        isSettingsLoaded = true;
        // Load settings into all already-ready iframes
        Object.keys(iframesReady).forEach(function (tabId) {
            if (iframesReady[tabId]) {
                setTimeout(function () {
                    loadSettingsToIframe(tabId);
                }, 100);
            }
        });
        // Always trigger load for currentTabId even if iframe reports ready late
        if (iframesReady[currentTabId]) {
            setTimeout(function () {
                loadSettingsToIframe(currentTabId);
            }, 100);
        } else {
            pendingLoads.add(currentTabId);
        }
        if (allSettings.cai_dat && allSettings.cai_dat.che_do_nha_phat_trien && allSettings.cai_dat.giao_dien_cai_dat_toi) {
            applyTheme('dark');
        }
        restoreSidebar();
        hideLoading();
        updateMinHeight();
    };
    window.addEventListener('DOMContentLoaded', function () {
        setTimeout(function () {
            if (window.sketchup) {
                window.sketchup.load_settings();
            } else {
                window.location.href = 'skp:load_settings';
            }
        }, 150);
    });
    if (document.readyState === 'loading') {
    } else {
        setTimeout(function () {
            if (window.sketchup) {
                window.sketchup.load_settings();
            } else {
                window.location.href = 'skp:load_settings';
            }
        }, 150);
    }
    switchToTab('cai_dat');
    function setTabTextVisible(visible) {
        var tabs = document.getElementById('tabs');
        var label = document.querySelector('.tabs-footer-label');
        if (visible) {
            tabs.classList.remove('hide-text');
        } else {
            tabs.classList.add('hide-text');
        }
        label.style.opacity = visible ? '1' : '0';
    }
    function applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        document.querySelectorAll('iframe').forEach(function(iframe) {
            try {
                if (iframe.contentDocument) {
                    iframe.contentDocument.documentElement.setAttribute('data-theme', theme);
                }
            } catch(e) {}
        });
    }
    function broadcastCol3(expanded) {
        document.querySelectorAll('iframe').forEach(function(iframe) {
            try {
                var col3 = iframe.contentDocument && iframe.contentDocument.querySelector('.col3');
                if (col3) col3.classList.toggle('expanded', expanded);
            } catch(e) {}
        });
    }
    function toggleSidebar() {
        var tabs = document.getElementById('tabs');
        var icon = document.querySelector('.tabs-footer-icon');
        var isCollapsing = !tabs.classList.contains('collapsed');
        if (isCollapsing) {
            setTabTextVisible(false);
            tabs.classList.add('collapsed');
        } else {
            tabs.classList.remove('collapsed');
            setTabTextVisible(true);
        }
        icon.textContent = isCollapsing ? '›' : '‹';
        broadcastCol3(isCollapsing);
        updateMinHeight();
        var tabId = 'cai_dat';
        var val = isCollapsing ? true : false;
        if (window.sketchup) {
            window.sketchup.save_setting(tabId + '@sidebar_collapsed@' + val);
        } else {
            window.location.href = 'skp:save_setting@' + tabId + '@sidebar_collapsed@' + val;
        }
    }
    function restoreSidebar() {
        if (allSettings.cai_dat && allSettings.cai_dat.sidebar_collapsed) {
            var tabs = document.getElementById('tabs');
            var icon = document.querySelector('.tabs-footer-icon');
            var label = document.querySelector('.tabs-footer-label');
            tabs.classList.add('collapsed');
            icon.textContent = '›';
            setTabTextVisible(false);
            broadcastCol3(true);
        }
    }
    function updateMinHeight() {}
</script>
</body>
</html>
  HTML
  def self.html
    base_url = "file:///" + File.join(__dir__, "..", "html", "").gsub("\\", "/")
    HTML.sub("BASE_PLACEHOLDER", "<base href=\"#{base_url}\">")
  end
end
