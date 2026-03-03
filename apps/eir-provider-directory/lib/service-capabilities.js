const VIDEO_ACTION_PATTERN =
  /video|videobesok|videobesök|videomote|videomöte|video(?:\s|-)?besok|video(?:\s|-)?möte|chat/i
const MVK_ACTION_PATTERN = /\bmvk\b|mina vardkontakter|mina vårdkontakter/i

export function hasVideoConsultation(provider) {
  const services = provider?.services || {}
  if (services.video_consultation === true) return true

  const actionTexts = collectActionTexts(provider)
  return actionTexts.some(text => VIDEO_ACTION_PATTERN.test(text))
}

export function hasMVKServices(provider) {
  const services = provider?.services || {}
  if (services.mvk_services === true) return true

  const actionTexts = collectActionTexts(provider)
  return actionTexts.some(text => MVK_ACTION_PATTERN.test(text))
}

export function collectActionTexts(provider) {
  const texts = []
  const services = provider?.services || {}

  const structured = Array.isArray(services.e_services_structured)
    ? services.e_services_structured
    : []
  for (const action of structured) {
    const text = String(action?.text || '').trim()
    const desc = String(action?.description_text || '').trim()
    if (text) texts.push(text)
    if (desc) texts.push(desc)
  }

  const simple = Array.isArray(services.e_services) ? services.e_services : []
  for (const item of simple) {
    if (typeof item === 'string' && item.trim()) texts.push(item.trim())
    if (item && typeof item === 'object') {
      const text = String(item.text || item.Text || '').trim()
      if (text) texts.push(text)
    }
  }

  return texts
}
