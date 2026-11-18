from pathlib import Path
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
    page=browser.new_page(viewport={'width':1440,'height':1050})
    errors=[]
    page.on('pageerror',lambda e:errors.append(str(e)))
    page.goto(Path('docs/芬布尔之冬模型清单/index.html').resolve().as_uri())
    assert page.locator('.model').count()==8
    assert page.locator('#quality-style').get_attribute('aria-pressed')=='true'
    page.locator('#engine-preview').click()
    assert page.locator('#viewer').is_visible()
    page.keyboard.press('Escape')
    page.locator('[data-id=quality_spike_trap] select').select_option(label='需修改')
    page.locator('[data-id=quality_spike_trap] textarea').fill('测试意见')
    page.locator('#dark-style').click()
    assert page.locator('.model').count()==8
    assert page.locator('#engine-preview').is_hidden()
    assert page.locator('[data-id=dark_rune_gate] textarea').input_value()==''
    page.locator('#original-style').click()
    assert page.locator('.model').count()==9
    page.locator('#quality-style').click()
    assert page.locator('[data-id=quality_spike_trap] textarea').input_value()=='测试意见'
    for image in page.locator('.model img').all(): image.evaluate('(i)=>i.loading="eager"')
    page.wait_for_function('Array.from(document.querySelectorAll(".model img, #assembly img")).every(i=>i.complete&&i.naturalWidth>0)')
    page.locator('[data-id=quality_spike_trap] .image-button').click()
    assert page.locator('#viewer').is_visible()
    page.keyboard.press('Escape')
    with page.expect_download() as event: page.locator('#export').click()
    download=event.value
    download.save_as('/tmp/quality-gate-review.json')
    import json
    result=json.loads(Path('/tmp/quality-gate-review.json').read_text())
    assert result['batch']=='task3d_rooms_quality_2026-11-15'
    assert len(result['models'])==8
    assert next(m for m in result['models'] if m['id']=='quality_spike_trap')['note']=='测试意见'
    for link in page.locator('.model .links a, #assembly-download, #manifest-download').all():
        assert Path('docs/芬布尔之冬模型清单',link.get_attribute('href')).resolve().exists()
    page.locator('#search').fill('地刺')
    assert page.locator('.model').count()==1
    page.locator('#search').fill('')
    page.evaluate('localStorage.clear()')
    page.reload()
    page.set_viewport_size({'width':390,'height':900})
    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    assert not errors,errors
    print('QUALITY_REVIEW_VERIFIED defaults=8 dark=8 original=9 notes=isolated export=correct previews=loaded downloads=exist mobile=no-overflow')
    browser.close()
