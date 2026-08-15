import asyncio, pathlib, sys, re
from playwright.async_api import async_playwright

ROOT=pathlib.Path(__file__).resolve().parents[1]
LEGACY=ROOT/'tests'/'browser-workflows-5.3.py'
ns={'__name__':'point3_fixture','__file__':str(LEGACY)}
src=LEGACY.read_text(encoding='utf-8').rsplit('asyncio.run(main())',1)[0]
exec(compile(src,str(LEGACY),'exec'),ns)

PROJECT=ns['projects'][0]['id']; SITE=ns['SITE']; CABINET=ns['CABINET']; MEMBERSHIP2=ns['MEMBERSHIP2']

async def mount(browser, route, actor='owner', viewport=(1500,1000)):
    page=await browser.new_page(viewport={'width':viewport[0],'height':viewport[1]})
    await ns['initialize'](page,'client',actor)
    await page.route('https://client.test/**',ns['local_route'])
    html=(ROOT/'index.html').read_text(encoding='utf-8').replace('<head>',f'<head><base href="https://client.test/"><script>location.hash="{route}"</script>',1)
    await page.set_content(html,wait_until='domcontentloaded')
    return page

async def no_overflow(page,label):
    m=await page.evaluate('({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:window.innerWidth})')
    assert m['doc']<=m['inner']+3 and m['body']<=m['inner']+3, f'{label} horizontal overflow: {m}'

async def scrollable(locator,label):
    v=await locator.evaluate("el=>{const o=getComputedStyle(el).overflowY;el.scrollTop=el.scrollHeight;const max=el.scrollTop;el.scrollTop=0;return {o,max,sh:el.scrollHeight,ch:el.clientHeight}}")
    assert v['o'] in ('auto','scroll'), f'{label} overflow-y={v}'
    return v

async def owner_point3(browser):
    ns['enable_pdc_contracts'](); ns['captured']['actor']='owner'; ns['captured']['pdc_calls'].clear()
    page=await mount(browser,'#/projects')
    await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
    assert await page.locator('.pdc-project-card').count()>=2
    await no_overflow(page,'Projects desktop')

    # Cards/List is a real user preference and does not duplicate the portfolio.
    await page.locator('[data-action="project-view"][data-view="list"]').click()
    assert await page.locator('.project-view-list').count()==1
    await page.locator('[data-action="project-view"][data-view="cards"]').click()
    assert await page.locator('.project-view-cards').count()==1

    # Full Project 360 -> Site 360 -> Cabinet 360, with deep links and no cramped drawers.
    await page.locator(f'[data-action="open-project"][data-id="{PROJECT}"]').first.click()
    await page.locator('.project360-context').wait_for(state='visible',timeout=5000)
    assert f'/project/{PROJECT}' in await page.evaluate('location.hash')
    assert await page.locator('.entity-workspace').count()==1
    assert await page.locator('.drawer:has(.project360-context)').count()==0
    await no_overflow(page,'Project 360 desktop')

    await page.locator(f'[data-action="open-site"][data-id="{SITE}"]').click()
    await page.locator('.site-context-hero').wait_for(state='visible',timeout=5000)
    assert f'/site/{SITE}' in await page.evaluate('location.hash')
    assert await page.locator('.site-cabinets-panel').count()==1
    await no_overflow(page,'Site 360 desktop')

    await page.locator(f'[data-action="open-cabinet"][data-id="{CABINET}"]').click()
    await page.locator('.cabinet-context-hero').wait_for(state='visible',timeout=5000)
    assert f'/cabinet/{CABINET}' in await page.evaluate('location.hash')
    assert await page.locator('.cabinet-record-area').count()==6
    body=page.locator('.entity-workspace-body')
    v=await scrollable(body,'Cabinet 360 workspace')
    # At tall desktop viewports content may fit; overflow must still be configured correctly.
    await no_overflow(page,'Cabinet 360 desktop')
    await page.screenshot(path='/mnt/data/optimum-point3-cabinet360-desktop.png',full_page=True)
    await page.close()

    # Direct deep links restore the correct workspace without walking the hierarchy first.
    for kind,ident,ready in [('project',PROJECT,'.project360-context'),('site',SITE,'.site-context-hero'),('cabinet',CABINET,'.cabinet-context-hero')]:
        p=await mount(browser,f'#/projects/{kind}/{ident}')
        await p.locator(ready).wait_for(state='visible',timeout=8000)
        assert await p.locator('.entity-workspace').count()==1
        await no_overflow(p,f'Deep link {kind}')
        await p.close()

    # At mobile height the Cabinet workspace must genuinely scroll.
    p=await mount(browser,f'#/projects/cabinet/{CABINET}',viewport=(390,844))
    await p.locator('.cabinet-context-hero').wait_for(state='visible',timeout=8000)
    mv=await scrollable(p.locator('.entity-workspace-body'),'Cabinet 360 mobile workspace')
    assert mv['max']>0, f'Cabinet 360 mobile should genuinely scroll: {mv}'
    await no_overflow(p,'Cabinet 360 mobile')
    await p.screenshot(path='/mnt/data/optimum-point3-cabinet360-mobile.png',full_page=True)
    await p.close()

async def carryover_and_localization(browser):
    ns['enable_pdc_contracts'](); ns['captured']['actor']='owner'
    page=await mount(browser,'#/team')
    await page.locator('.team-directory-shell').wait_for(state='visible',timeout=8000)

    # Member 360 is centered, scrollable, and View as User is a product-oriented preview.
    await page.locator(f'[data-action="orgos-member360"][data-id="{MEMBERSHIP2}"]').first.evaluate('el=>el.click()')
    await page.locator('.member360-v2').wait_for(state='visible',timeout=5000)
    box=await page.locator('.member360-dialog').bounding_box()
    assert box and box['x']>150 and box['x']+box['width']<1350, f'Member 360 not centered enough: {box}'
    await scrollable(page.locator('.member360-dialog .dialog-body'),'Member 360')
    await page.locator('[data-action="orgos-member-tab"][data-tab="access"]').click()
    await page.locator(f'[data-action="access55-view-user"][data-id="{MEMBERSHIP2}"]').click()
    await page.locator('.access-preview-v2').wait_for(state='visible',timeout=5000)
    assert await page.locator('.access-visible-pages').count()==1
    assert await page.locator('.access-capability-groups').count()==1
    assert await page.locator('.access-preview-secondary').count()<=1
    await page.screenshot(path='/mnt/data/optimum-point3-access-preview-desktop.png',full_page=True)
    await page.locator('[data-action="close-overlay"]').first.click()

    # Member creation keeps role first and puts exceptional access in a clearly optional section.
    await page.locator('[data-action="invite-member"]').first.click()
    await page.locator('form[data-form="provision-member"]').wait_for(state='visible',timeout=4000)
    assert await page.locator('.member-access-advanced').count()==1
    txt=(await page.locator('.member-access-advanced').inner_text())
    assert 'اختياري' in txt or 'متقدم' in txt or 'الوصول' in txt
    await page.locator('[data-action="close-overlay"]').first.click()

    # Arabic mode does not expose raw technical permission keys in role UI.
    await page.locator('[data-nav="roles"]').click()
    await page.locator('.role-capability-list').wait_for(state='visible',timeout=5000)
    assert await page.locator('.permission-technical-key:visible').count()==0

    # Scope error is inline/localized before RPC, not a delayed server-only error.
    await page.locator('[data-action="new-role"]').first.click()
    form=page.locator('form[data-form="access55-role-draft"]')
    await form.wait_for(state='visible',timeout=4000)
    await form.locator('input[name="name_ar"]').fill('دور اختبار النطاق')
    await form.locator('input[name="name_en"]').fill('Scope QA Role')
    await form.locator('input[name="slug"]').fill('scope-qa-role')
    await form.locator('input[name="change_note"]').fill('اختبار رسالة النطاق')
    if await form.locator('input[name="permission"]:checked').count()==0:
        await form.locator('input[name="permission"]:not([disabled])').first.evaluate("el=>{el.checked=true;el.dispatchEvent(new Event('change',{bubbles:true}))}")
    row=form.locator('.scope-rule-row').first
    await row.locator('[name="scope_type"]').select_option('project')
    # Deliberately leave target empty.
    await form.locator('button[type="submit"]').click()
    await page.locator('.scope-inline-error').wait_for(state='visible',timeout=2500)
    err=await page.locator('.scope-inline-error').inner_text()
    assert 'اختر' in err and 'النطاق' in err
    assert await row.locator('[name="scope_target"]').get_attribute('aria-invalid')=='true'
    await page.screenshot(path='/mnt/data/optimum-point3-role-inline-error.png',full_page=True)
    await page.close()

async def immediate_progress(browser):
    ns['enable_pdc_contracts'](); ns['captured']['actor']='owner'
    page=await mount(browser,'#/projects')
    await page.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
    await page.locator('[data-action="new-project"]').first.click()
    form=page.locator('form[data-form="project"]'); await form.wait_for(state='visible',timeout=4000)
    # Fill only fields marked required, with safe generic values by input name.
    required=await form.locator('input[required],select[required],textarea[required]').all()
    for i,el in enumerate(required):
        tag=await el.evaluate('e=>e.tagName.toLowerCase()'); name=await el.get_attribute('name') or ''
        if tag=='select':
            opts=await el.locator('option:not([disabled])').all()
            if opts:
                values=[await o.get_attribute('value') for o in opts]
                values=[x for x in values if x]
                if values: await el.select_option(values[0])
        else:
            current=await el.input_value()
            if not current:
                value={'name':'مشروع اختبار التحميل','code':'LOAD-QA'}.get(name,f'اختبار {i+1}')
                await el.fill(value)
    # Delay the real fetch at browser level; UI must announce progress immediately.
    await page.evaluate('''()=>{const original=window.fetch.bind(window);window.fetch=async (...args)=>{const u=String(args[0]||'');if(u.includes('/rpc/save_project'))await new Promise(r=>setTimeout(r,900));return original(...args)}}''')
    await form.locator('button[type="submit"]').click()
    status=page.locator('.form-operation-status')
    await status.wait_for(state='visible',timeout=500)
    text=await status.inner_text(); assert 'جار' in text and ('حفظ' in text or 'تنفيذ' in text)
    assert await form.get_attribute('aria-busy')=='true'
    await page.screenshot(path='/mnt/data/optimum-point3-immediate-progress.png',full_page=True)
    await page.close()

async def limited_permission_ui(browser):
    ns['captured']['disabled_entitlements']=set(); ns['captured']['actor']='engineer'
    page=await mount(browser,'#/team','engineer',(390,844))
    await page.locator('.team-directory-shell').wait_for(state='visible',timeout=8000)
    # No permission means navigation itself is absent, not a clickable dead end.
    assert await page.locator('[data-nav="activity"]').count()==0
    # The fixture grants projects.view but not projects.create: view stays visible while create is hidden.
    assert await page.locator('[data-nav="projects"]').count()==1
    assert await page.locator('[data-action="new-project"]').count()==0
    await page.locator(f'[data-action="orgos-member360"][data-id="{MEMBERSHIP2}"]').first.evaluate('el=>el.click()')
    await page.locator('.member360-v2').wait_for(state='visible',timeout=5000)
    assert await page.locator('[data-action="orgos-member-tab"][data-tab="activity"]').count()==0
    box=await page.locator('.member360-dialog').bounding_box(); assert box and box['x']>=6 and box['x']+box['width']<=384, box
    await no_overflow(page,'Limited mobile Member 360')
    await page.screenshot(path='/mnt/data/optimum-point3-limited-mobile.png',full_page=True)
    await page.close()

async def main():
    async with async_playwright() as pw:
        browser=await pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
        for name,fn in [('owner-point3',owner_point3),('carryover-localization',carryover_and_localization),('immediate-progress',immediate_progress),('limited-permission-ui',limited_permission_ui)]:
            print('POINT3 BROWSER',name,'START',flush=True)
            await fn(browser)
            print('POINT3 BROWSER',name,'PASS',flush=True)
        await browser.close()
    print('PASS Point 3 browser QA: desktop/mobile/deep-links/permissions/loading/localization',flush=True)

if __name__=='__main__': asyncio.run(main())
