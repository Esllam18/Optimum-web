import asyncio, pathlib, sys
from playwright.async_api import async_playwright

ROOT=pathlib.Path(__file__).resolve().parents[1]
LEGACY=ROOT/'tests'/'browser-workflows-5.3.py'
ns={'__name__':'point4_fixture','__file__':str(LEGACY)}
src=LEGACY.read_text(encoding='utf-8').rsplit('asyncio.run(main())',1)[0]
exec(compile(src,str(LEGACY),'exec'),ns)
PROJECT=ns['projects'][0]['id']; TASK=ns['TASK']

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

async def simple_tasks_owner(browser):
    ns['captured']['actor']='owner'; ns['captured']['work_calls'].clear()
    p=await mount(browser,'#/tasks')
    await p.locator('.simple-work-home').wait_for(state='visible',timeout=8000)
    assert await p.locator('.workos-cockpit:visible').count()==0
    assert await p.locator('.workos-kpis:visible').count()==0
    assert await p.locator('.simple-work-tabs button').count()>=4
    assert await p.locator('.simple-quick-add').count()==1
    assert await p.locator('.simple-task-line').count()>=1
    assert await p.locator('.simple-next-action').count()==1
    assert await p.locator('.simple-day-rail').count()==1
    assert await p.locator('[data-action="workos-plan-day"]').count()==1
    assert await p.locator('.simple-layout-toggle').count()==1
    assert await p.locator('.simple-task-context-chips').count()>=1
    assert 'المهام' in (await p.locator('main').inner_text())
    await no_overflow(p,'Point 4 desktop')
    await p.screenshot(path='/mnt/data/optimum-point4-tasks-home-desktop.png',full_page=True)

    # Day planner is advisory and only changes the local focus set.
    await p.locator('[data-action="workos-plan-day"]').click()
    assert await p.locator('.simple-task-line.is-focused').count()>=1

    # Board is an optional alternate view, not the default.
    await p.locator('[data-action="workos-simple-view"][data-view="all"]').click()
    await p.locator('[data-action="workos-simple-layout"][data-layout="board"]').click()
    await p.locator('.simple-board').wait_for(state='visible',timeout=3000)
    await p.screenshot(path='/mnt/data/optimum-point4-board-desktop.png',full_page=True)
    await p.locator('[data-action="workos-simple-view"][data-view="team"]').click()
    await p.locator('[data-action="workos-simple-layout"][data-layout="list"]').click()
    assert await p.locator('.simple-task-group').count()>=1
    await p.screenshot(path='/mnt/data/optimum-point4-team-desktop.png',full_page=True)
    await p.locator('[data-action="workos-simple-view"][data-view="today"]').click()
    await p.wait_for_timeout(250)

    # Quick add announces server work immediately instead of silent waiting.
    await p.evaluate('''()=>{const original=window.fetch.bind(window);window.fetch=async (...args)=>{const u=String(args[0]||'');if(u.includes('/rpc/save_work_item'))await new Promise(r=>setTimeout(r,700));return original(...args)}}''')
    form=p.locator('form[data-form="workos-quick-task"]')
    await form.locator('[name="title"]').fill('مراجعة تسليم الكابينة')
    await form.locator('button[type="submit"]').click()
    status=form.locator('.form-operation-status')
    await status.wait_for(state='visible',timeout=400)
    txt=await status.inner_text(); assert 'جار' in txt and ('إضافة' in txt or 'مهمة' in txt)
    await p.wait_for_timeout(850)

    # Task detail stays calm and the smart breakdown is optional/advisory.
    await p.locator(f'[data-action="open-task"][data-id="{TASK}"]').first.click()
    await p.locator('.point4-task-detail').wait_for(state='visible',timeout=5000)
    assert await p.locator('[data-action="workos-how-to"]').count()==1
    await p.locator('[data-action="workos-how-to"]').click()
    await p.locator('.task-howto').wait_for(state='visible',timeout=3000)
    assert await p.locator('.task-howto li').count()>=4
    await p.locator('[data-action="close-overlay"]').first.click()
    await p.locator(f'[data-action="open-task"][data-id="{TASK}"]').first.click()
    await p.locator('.point4-task-detail').wait_for(state='visible',timeout=5000)
    assert await p.locator('[data-action="workos-smart-breakdown"]').count()>=1
    await p.locator('[data-action="workos-smart-breakdown"]').first.click()
    await p.locator('form[data-form="workos-smart-breakdown"]').wait_for(state='visible',timeout=4000)
    text=await p.locator('.smart-breakdown-intro').inner_text()
    assert 'لن ينفذ' in text or 'اقتراح' in text
    assert await p.locator('.smart-breakdown-list > label').count()>=4
    await p.locator('[data-action="close-overlay"]').first.click()

    # Edit is essentials-first with explicit advanced disclosure.
    await p.locator(f'[data-action="open-task"][data-id="{TASK}"]').first.click()
    await p.locator('[data-action="edit-task"]').first.click()
    edit=p.locator('form[data-form="workos-task"]'); await edit.wait_for(state='visible',timeout=4000)
    assert await edit.locator('.point4-task-context-card').count()==1
    assert await edit.locator('.point4-task-advanced').count()==1
    assert await edit.locator('[data-workos-cabinet]').count()==1
    await p.locator('[data-action="close-overlay"]').first.click()
    await p.screenshot(path='/mnt/data/optimum-point4-task-edit-desktop.png',full_page=True)
    await p.close()

async def calendar_progress(browser):
    ns['captured']['actor']='owner'; ns['captured']['work_calls'].clear()
    p=await mount(browser,'#/calendar')
    await p.locator('.workos-calendar-shell').wait_for(state='visible',timeout=8000)
    for view in ['day','week','month']:
        assert await p.locator(f'[data-action="workos-calendar-view"][data-view="{view}"]').count()==1
    await p.locator('[data-action="workos-calendar-view"][data-view="month"]').click()
    drag=p.locator('[data-workos-drag-task]').first
    assert await drag.count()==1
    await p.evaluate('''()=>{const original=window.fetch.bind(window);window.fetch=async (...args)=>{const u=String(args[0]||'');if(u.includes('/rpc/save_work_item'))await new Promise(r=>setTimeout(r,700));return original(...args)}}''')
    await p.evaluate('''()=>{const src=document.querySelector('[data-workos-drag-task]');const zones=[...document.querySelectorAll('[data-workos-drop-date]')];const dst=zones[zones.length-1];const dt=new DataTransfer();src.dispatchEvent(new DragEvent('dragstart',{bubbles:true,dataTransfer:dt}));dst.dispatchEvent(new DragEvent('dragover',{bubbles:true,cancelable:true,dataTransfer:dt}));dst.dispatchEvent(new DragEvent('drop',{bubbles:true,cancelable:true,dataTransfer:dt}));}''')
    await p.locator('.workos-calendar-update-state').wait_for(state='visible',timeout=350)
    assert 'جار' in await p.locator('.workos-calendar-update-state').inner_text()
    await no_overflow(p,'Point 4 calendar')
    await p.screenshot(path='/mnt/data/optimum-point4-calendar-progress.png',full_page=True)
    await p.close()

async def project_context_and_focus_regression(browser):
    ns['enable_pdc_contracts'](); ns['captured']['actor']='owner'
    p=await mount(browser,f'#/projects/project/{PROJECT}')
    await p.locator('.project360-context').wait_for(state='visible',timeout=8000)
    await p.locator('.entity-workspace [data-action="project-open-work"]').click()
    await p.locator('.simple-work-home').wait_for(state='visible',timeout=5000)
    ctx=await p.locator('.simple-quick-context').inner_text()
    assert 'Alpha Project' in ctx
    await p.close()

    # Regression for the user's Point 3 screenshot: successful create must not crash on delayed focus restore.
    p=await mount(browser,'#/projects')
    await p.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=8000)
    await p.locator('[data-action="new-project"]').first.click()
    form=p.locator('form[data-form="project"]'); await form.wait_for(state='visible',timeout=4000)
    req=await form.locator('input[required],select[required],textarea[required]').all()
    for i,el in enumerate(req):
        tag=await el.evaluate('e=>e.tagName.toLowerCase()'); name=await el.get_attribute('name') or ''
        if tag=='select':
            vals=await el.locator('option').evaluate_all("els=>els.map(x=>x.value).filter(Boolean)")
            if vals: await el.select_option(vals[0])
        elif not await el.input_value():
            await el.fill({'name':'مشروع اختبار التركيز','code':'FOCUS-QA'}.get(name,f'اختبار {i+1}'))
    await form.locator('button[type="submit"]').click()
    await p.locator('.project-portfolio-toolbar').wait_for(state='visible',timeout=5000)
    await p.wait_for_timeout(250)
    assert await p.locator('.boot-error,.boot-failure').count()==0
    assert 'Cannot read properties of null' not in await p.locator('body').inner_text()
    await p.close()

async def mobile_and_permissions(browser):
    ns['captured']['actor']='engineer'
    p=await mount(browser,'#/tasks','engineer',(390,844))
    await p.locator('.simple-work-home').wait_for(state='visible',timeout=8000)
    assert await p.locator('[data-action="workos-simple-view"][data-view="team"]').count()==0
    assert await p.locator('[data-action="workos-admin"]').count()==0
    await no_overflow(p,'Point 4 limited mobile')
    await p.screenshot(path='/mnt/data/optimum-point4-simple-tasks-mobile.png',full_page=True)
    await p.close()

async def main():
    async with async_playwright() as pw:
        browser=await pw.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
        flows=[('simple-owner',simple_tasks_owner),('calendar-progress',calendar_progress),('context-focus-regression',project_context_and_focus_regression),('mobile-permissions',mobile_and_permissions)]
        wanted=set(sys.argv[1:])
        if wanted: flows=[x for x in flows if x[0] in wanted]
        for name,fn in flows:
            print('POINT4 BROWSER',name,'START',flush=True)
            await fn(browser)
            print('POINT4 BROWSER',name,'PASS',flush=True)
        await browser.close()
    print('PASS Point 4 browser QA: simple tasks, smart breakdown, calendar progress, context cascade, focus regression, mobile permissions',flush=True)

if __name__=='__main__': asyncio.run(main())
