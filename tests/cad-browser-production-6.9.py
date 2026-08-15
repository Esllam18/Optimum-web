from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]

def inline_harness(archived=False):
    html = (ROOT/'tests/cad-harness.html').read_text()
    js = (ROOT/'assets/engineering.js').read_text()
    css = (ROOT/'assets/styles.css').read_text()
    html = html.replace('<link rel="stylesheet" href="../assets/styles.css?v=4.8.0">', f'<style>{css}</style>')
    html = html.replace("import {createEngineeringModule,normalizeEngineeringSnapshot} from '../assets/engineering.js?v=4.8.0';", js)
    if archived:
        html = html.replace(
            "current_revision_id:'rev1',status:'draft',updated_at:new Date().toISOString()",
            "current_revision_id:'rev1',status:'draft',archived_at:'2026-08-12T00:00:00Z',updated_at:new Date().toISOString()",
            1,
        )
    return html

LOCAL_STORAGE_SHIM = """(() => {
  const values={};
  const storage={
    get length(){return Object.keys(values).length},
    key(i){return Object.keys(values)[i]??null},
    getItem(k){return Object.prototype.hasOwnProperty.call(values,k)?String(values[k]):null},
    setItem(k,v){values[k]=String(v)},
    removeItem(k){delete values[k]},
    clear(){for(const k of Object.keys(values))delete values[k]}
  };
  Object.defineProperty(window,'localStorage',{configurable:true,value:storage});
})()"""

def run_case(browser, name, width, height, archived=False):
    page = browser.new_page(viewport={'width':width,'height':height})
    errors=[]
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.evaluate(LOCAL_STORAGE_SHIM)
    page.set_content(inline_harness(archived=archived), wait_until='domcontentloaded', timeout=30000)
    page.wait_for_function('window.__cadReady===true', timeout=30000)
    page.wait_for_timeout(120)

    assert not errors, f'{name}: page errors: {errors}'
    overflow = page.evaluate('document.documentElement.scrollWidth-document.documentElement.clientWidth')
    assert overflow <= 1, f'{name}: horizontal overflow {overflow}px'
    for selector in ['.engineering-editor-body','.engineering-canvas-viewport','.cad-workspace-nav']:
        assert page.locator(selector).count() == 1, f'{name}: missing {selector}'

    if archived:
        assert page.locator('.cad-readonly-context').count() == 1, f'{name}: archived context banner missing'
        assert page.locator('.cad-master-library').count() == 0, f'{name}: editable element library leaked into archived context'
        assert page.locator('[data-action="engineering-tool"][data-tool="node"]').count() == 0, f'{name}: node tool leaked into archived context'
        assert page.locator('[data-action="engineering-tool"][data-tool="route"]').count() == 0, f'{name}: route tool leaked into archived context'
        assert page.locator('[data-action="engineering-frame-settings"]').count() == 0, f'{name}: frame edit leaked into archived context'
        for selector in ['[data-action="engineering-save"]','[data-action="engineering-new-revision"]','[data-action="engineering-publish"]']:
            assert page.locator(selector).count() == 0, f'{name}: mutation control leaked into archived context: {selector}'
    else:
        assert page.locator('.cad-master-library').count() == 1, f'{name}: editable element library missing'
        assert page.locator('.cad-readonly-context').count() == 0, f'{name}: false read-only banner'

    print(f'{name}: PASS overflow={overflow}px archived={archived}')
    page.close()

with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
    run_case(browser, 'cad-desktop-rtl', 1440, 1000)
    run_case(browser, 'cad-mobile-rtl', 390, 844)
    run_case(browser, 'cad-archived-readonly', 1280, 900, archived=True)
    browser.close()

print('Phase 6.9 CAD browser production checks passed.')
