"use strict";(()=>{var Nt={necessary:[],functional:["functionality_storage","personalization_storage"],analytics:["analytics_storage"],communications:[],marketing:["ad_storage","ad_user_data","ad_personalization"]};function Se(e){let t={security_storage:"granted"};for(let[o,r]of Object.entries(Nt)){let a=!!e[o];for(let i of r)t[i]=a?"granted":"denied"}return t}var At="compliant-embedded",Dt=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,Mt=["banner","prefs","dsr","grievance","age_gate","hidden"];function Ce(e){if(!e||typeof e!="object")return!1;let t=e;if(t.source!==At)return!1;switch(t.type){case"init":return typeof t.siteKey=="string"&&t.siteKey.length>0&&typeof t.apiBase=="string"&&typeof t.visitorId=="string"&&Dt.test(t.visitorId)&&!!t.config&&typeof t.config=="object";case"view":return typeof t.view=="string"&&Mt.includes(t.view);case"catalog":return typeof t.lang=="string"&&"catalog"in t&&(t.catalog===null||typeof t.catalog=="object");case"httpResult":return typeof t.id=="string"&&!!t.result&&typeof t.result=="object";default:return!1}}function C(e){let t=JSON.stringify(e);try{if(window.CompliantAndroid){window.CompliantAndroid.post(t);return}if(window.ReactNativeWebView){window.ReactNativeWebView.postMessage(t);return}if(window.compliant){window.compliant.postMessage(t);return}window.webkit?.messageHandlers?.compliant?.postMessage(t)}catch{}}var ae=[],ie=null;function It(e){if(typeof e!="string")return e;try{return JSON.parse(e)}catch{return null}}function Ot(e){let t=It(e);if(!Ce(t)){C({type:"error",message:"malformed host message"});return}ie?ie(t):ae.push(t)}window.__compliantHostMessage=Ot;function Ee(e){for(ie=e;ae.length>0;){let t=ae.shift();t&&e(t)}}var Ht=8e3,Gt=0,U=new Map;function Re(e,t,o){let r=`req_${++Gt}`;return new Promise(a=>{let i=setTimeout(()=>{U.delete(r),a({ok:!1,error:"network"})},Ht);U.set(r,{settle:a,timer:i}),C({type:"httpRequest",id:r,method:e,path:t,body:o})})}function ke(e){let t=U.get(e.id);t&&(U.delete(e.id),clearTimeout(t.timer),t.settle(e.result))}function Te(e){return Re("GET",e)}function E(e,t){return Re("POST",e,t)}var ce=new Map,se=new Set,le=new Map;function O(e){return ce.get(e)??null}function F(e,t){e==="en"||ce.has(e)||se.has(e)||(se.add(e),le.set(e,t),C({type:"catalogRequest",lang:e}))}function _e(e){se.add(e.lang);let t=le.get(e.lang);le.delete(e.lang),e.catalog&&(ce.set(e.lang,e.catalog),t?.())}var g={siteKey:"",apiBase:"",cdnBase:""};function Pe(e){g.siteKey=e.siteKey,g.apiBase=e.apiBase}var de="",H=null,j=null;function Le(e){de=e.visitorId,H=e.prefs,j=e.lang}function pe(){C({type:"persist",prefs:H,lang:j})}function _(){return de||C({type:"error",message:"no visitor id: the shell did not seed one"}),de}function Ne(){return H}function P(e){return H=e,pe(),!0}function Ae(e){return H=e,pe(),!0}function De(){return j}function Me(e){return j=e,pe(),!0}function Ie(){return"unknown"}var q={config:null,configFailed:!1,view:"hidden",showReopen:!1,draft:{},draftPurposes:{},saved:null,dsrStatus:"idle",dsrError:null,grievanceStatus:"idle",grievanceError:null,lang:"en",langMenuOpen:!1,langMenuPos:null,receiptStatus:"idle",historyStatus:"idle",wasReprompted:!1,gpcNotice:!1,presumedCategories:null,presumedActiveNotice:!1,isNarrow:!1,activeTab:"consent",declaration:null,declarationStatus:"idle",parentalCapacity:null},Oe=null;function c(){return q}function s(e){q={...q,...e},Oe?.(q)}function He(e){Oe=e}function Vt(e){let t=e.geo?.outcome??"opt_in";if(t==="opt_in")return null;let o={};for(let r of e.categories??[])o[r]=t==="opt_out"?!0:r==="necessary";return o}function Ge(e){let t=e.geo?.outcome??"opt_in";t!=="opt_in"&&s({view:"hidden",showReopen:t==="opt_out",presumedCategories:Vt(e)})}var ue=["en","as","bn","brx","doi","gu","hi","kn","ks","kok","mai","ml","mni","mr","ne","or","pa","sa","sat","sd","ta","te","ur"],Bt={en:{englishName:"English",nativeName:"English",script:"Latin",textDirection:"ltr"},as:{englishName:"Assamese",nativeName:"অসমীয়া",script:"Bengali-Assamese",textDirection:"ltr"},bn:{englishName:"Bengali",nativeName:"বাংলা",script:"Bengali",textDirection:"ltr"},brx:{englishName:"Bodo",nativeName:"बड़ो",script:"Devanagari",textDirection:"ltr"},doi:{englishName:"Dogri",nativeName:"डोगरी",script:"Devanagari",textDirection:"ltr"},gu:{englishName:"Gujarati",nativeName:"ગુજરાતી",script:"Gujarati",textDirection:"ltr"},hi:{englishName:"Hindi",nativeName:"हिन्दी",script:"Devanagari",textDirection:"ltr"},kn:{englishName:"Kannada",nativeName:"ಕನ್ನಡ",script:"Kannada",textDirection:"ltr"},ks:{englishName:"Kashmiri",nativeName:"کٲشُر",script:"Perso-Arabic",textDirection:"rtl"},kok:{englishName:"Konkani",nativeName:"कोंकणी",script:"Devanagari",textDirection:"ltr"},mai:{englishName:"Maithili",nativeName:"मैथिली",script:"Devanagari",textDirection:"ltr"},ml:{englishName:"Malayalam",nativeName:"മലയാളം",script:"Malayalam",textDirection:"ltr"},mni:{englishName:"Manipuri (Meitei)",nativeName:"ꯃꯤꯇꯩꯂꯣꯟ",script:"Meitei Mayek",textDirection:"ltr"},mr:{englishName:"Marathi",nativeName:"मराठी",script:"Devanagari",textDirection:"ltr"},ne:{englishName:"Nepali",nativeName:"नेपाली",script:"Devanagari",textDirection:"ltr"},or:{englishName:"Odia",nativeName:"ଓଡ଼ିଆ",script:"Odia",textDirection:"ltr"},pa:{englishName:"Punjabi",nativeName:"ਪੰਜਾਬੀ",script:"Gurmukhi",textDirection:"ltr"},sa:{englishName:"Sanskrit",nativeName:"संस्कृतम्",script:"Devanagari",textDirection:"ltr"},sat:{englishName:"Santali",nativeName:"ᱥᱟᱱᱛᱟᱲᱤ",script:"Ol Chiki",textDirection:"ltr"},sd:{englishName:"Sindhi",nativeName:"سنڌي",script:"Perso-Arabic",textDirection:"rtl"},ta:{englishName:"Tamil",nativeName:"தமிழ்",script:"Tamil",textDirection:"ltr"},te:{englishName:"Telugu",nativeName:"తెలుగు",script:"Telugu",textDirection:"ltr"},ur:{englishName:"Urdu",nativeName:"اردو",script:"Perso-Arabic",textDirection:"rtl"}};function K(e){return ue.includes(e)}function G(e){return K(e)?Bt[e]:void 0}function z(e){return ue.filter(t=>e.languages.includes(t))}function Be(e){let t=De();if(t&&K(t)&&e.languages.includes(t))return t;let o=e.defaultLang;return K(o)?o:"en"}function Ue(e){s({lang:e,langMenuOpen:!1,declaration:null,declarationStatus:"idle"});let t=c().config;Me(e,t?void 0:void 0),F(e,()=>s({lang:c().lang}))}var Fe={copy:{bannerTitle:"We use cookies and similar technologies",bannerDescription:"We use cookies to operate this site and, with your consent, for functional, analytics, and communications purposes.",acceptAll:"Accept all",rejectNonEssential:"Reject non-essential",managePreferences:"Manage preferences",savePreferences:"Save preferences",withdrawConsent:"Withdraw consent",withdrawnNotice:"Consent withdrawn.",reopenLabel:"Privacy preferences",submitDataRequest:"Submit a data request",fileGrievance:"File a grievance",backToPreferences:"Back to preferences",submit:"Submit",fullName:"Full name",email:"Email",description:"Description",requestType:"Request type",category:"Category",submitError:"Couldn't submit — please try again.",submitSuccessDsr:"Your request has been submitted.",submitSuccessGrievance:"Your grievance has been submitted.",downloadReceipt:"Download receipt",receiptError:"Couldn't download the receipt — please try again.",downloadHistory:"Download my consent history",historyError:"Couldn't download your consent history — please try again.",languageLabel:"Language",gpcNotice:"We noticed a Global Privacy Control signal from your browser and limited non-essential data collection accordingly. You can change this anytime below.",presumedActiveNotice:"Non-essential cookies are currently active for your region. Turn them off below and save to opt out.",renewalNotice:"Your preferences are stored for {days} days on this device. Some browsers, including Safari, may clear this sooner without a visit.",purposeRetention:"Kept for {days} days",purposeBasis:"Lawful basis: {basis}",purposeChanged:"Updated",lawfulBasisConsent:"Consent",lawfulBasisLegitimateUse:"Legitimate use",lawfulBasisVoluntary:"Voluntary",purposeDataItems:"Personal data collected ({count})",categoryPurposesToggle:"Purposes ({count})",sensitivityLabels:{personal:"Personal",sensitive:"Sensitive",financial:"Financial",health:"Health",children:"Children's data"},otpPrompt:"We've emailed you a 6-digit verification code. Enter it below to confirm this request.",verificationCodeLabel:"Verification code",verifyCode:"Verify",verifyError:"Incorrect or expired code — please try again.",ageGateNotice:"By choosing Accept or Reject below, you confirm you are 18 years or older per DPDP Act, Section 9.",ageGateUnder18Link:"I am under 18",ageGateTitle:"Parental Consent Required",ageGateBody:"Under DPDP Act Section 9, processing personal data of individuals under 18 requires verifiable parental or guardian consent. We have limited data collection to only essential cookies until that consent is provided.",ageGateRestrictionNote:"No analytics, marketing, or behavioral tracking data will be collected.",ageGateContactLead:"To provide parental consent, contact:",ageGateGoBack:"Go back",ageGateIUnderstand:"I understand",ageGateRestrictedStatus:"Restricted (Minor)",ageGatePendingNote:"Age-gated · parental consent pending.",ageGateVerifyTitle:"Confirm your age",ageGateVerifyIntro:"Enter your email address. We'll send a 6-digit code to confirm your age before you continue.",ageGateSendCode:"Send code",ageGateDobIntro:"Enter your date of birth to complete the age check.",ageGateDobLabel:"Date of birth",ageGateContinue:"Continue",requestTypeLabels:{access:"Access my data",correction:"Correct my data",erasure:"Erase my data",nomination:"Nominate a representative",withdrawal:"Withdraw my consent"},grievanceCategoryLabels:{consent_handling:"Consent violation",data_accuracy:"Data quality / accuracy",erasure_delay:"Erasure delay",unsolicited_communication:"Unsolicited communication",data_breach:"Data breach",unauthorised_processing:"Unauthorised processing",rights_not_honoured:"Rights not honoured",excessive_collection:"Excessive data collection",retention_violation:"Retention violation",third_party_sharing:"Unauthorised third-party sharing",childrens_data_misuse:"Children's data misuse",cross_border_transfer:"Cross-border transfer violation",other:"Other"},declarationTitle:"Cookie declaration",declarationColumnName:"Name",declarationColumnType:"Type",declarationColumnPurpose:"Purpose",declarationColumnRetention:"Retention",declarationTypeLabels:{"HTTP Cookie":"HTTP Cookie","HTML Local Storage":"HTML Local Storage","HTML Session Storage":"HTML Session Storage","HTML Storage":"HTML Storage","Pixel Tracker":"Pixel Tracker",Script:"Script",IFrame:"IFrame","Resource Hint":"Resource Hint"},declarationRetentionPersistent:"Persistent — remains until the site or visitor clears it",declarationRetentionSession:"Session — cleared when the browser tab closes",declarationRetentionNotObserved:"Not observed in this scan",declarationRetentionLessThanHour:"Less than an hour",declarationRetentionHour:"1 hour",declarationRetentionHoursPlural:"{count} hours",declarationRetentionDay:"1 day",declarationRetentionDaysPlural:"{count} days",declarationRetentionYear:"1 year",declarationRetentionYearsPlural:"{count} years",declarationPreConsentWarning:"⚠ Observed firing before consent in our latest scan",declarationUnclassifiedLabel:"Not yet classified",declarationPrivacyPolicyLink:"Privacy policy",declarationEmptyState:"No cookies or trackers have been recorded for this site yet.",declarationLoading:"Loading…",declarationLoadError:"Something went wrong loading the cookie list — please try again.",tabConsent:"Consent",tabDetails:"Details",tabAbout:"About",aboutDataController:"Data controller",aboutDpo:"Data Protection Officer",aboutPurpose:"Purpose",aboutLinks:"Links",aboutExerciseRights:"Exercise your rights",aboutDeclaration:"Declaration",aboutDeclarationVersion:"Version {version} · published {date}",aboutBoardComplaintLink:"Complain to the Data Protection Board"},categories:{necessary:{label:"Strictly Necessary",description:"Required for the site to function. Cannot be turned off."},functional:{label:"Functional",description:"Enables enhanced functionality and personalization."},analytics:{label:"Analytics & Performance",description:"Helps us understand how visitors use the site."},communications:{label:"Communications",description:"Allows us to contact you with updates and offers."},marketing:{label:"Marketing",description:"Allows us to show you personalised ads and measure their performance."}}};var k=Fe;function Ft(e){return e==="en"?k:O(e)??k}function u(){let e=c().lang;if(e==="en")return k.copy;let t=O(e)?.copy;return t?{...k.copy,...t,requestTypeLabels:{...k.copy.requestTypeLabels,...t.requestTypeLabels},grievanceCategoryLabels:{...k.copy.grievanceCategoryLabels,...t.grievanceCategoryLabels},declarationTypeLabels:{...k.copy.declarationTypeLabels,...t.declarationTypeLabels},sensitivityLabels:{...k.copy.sensitivityLabels,...t.sensitivityLabels}}:k.copy}function je(e,t,o){let a=t?.categories?.[e]?.[o],i={...k.categories[e],...Ft(o).categories[e]};return{label:a?.label??i?.label??e,description:a?.description??i?.description??""}}function n(e,t={},o=[]){let r=document.createElement(e);for(let[a,i]of Object.entries(t))i!==void 0&&(typeof i=="function"?a.startsWith("on")&&r.addEventListener(a.slice(2).toLowerCase(),i):typeof i=="boolean"?i&&r.setAttribute(a,""):r.setAttribute(a,i));for(let a of o)a!=null&&r.append(typeof a=="string"?document.createTextNode(a):a);return r}function qe(){return!0}var me=!1,$=null;function V(e){if(e===me)return;let t=typeof document<"u"?document.documentElement:null;if(t){if(e){let r=window.innerWidth-t.clientWidth,a=r>0&&r<=40?r:0;$={overflow:t.style.overflow,paddingRight:t.style.paddingRight},t.style.overflow="hidden",a>0&&(t.style.paddingRight=`${a}px`),me=!0;return}t.style.overflow=$?.overflow??"",t.style.paddingRight=$?.paddingRight??"",$=null,me=!1}}function W(){return`
:host{all:initial;display:block;font-weight:400;font-size:14px;line-height:1.45;font-family:var(--cmp-font,system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif);color:var(--cmp-text,#101828);}
/*
 * font:'inherit' -- render.ts toggles this attribute on the shadow host
 * (theme.ts's themeFontIsInherited()) rather than routing the CSS-wide
 * keyword inherit through the --cmp-font custom property above: custom
 * properties do not support substituting CSS-wide keywords through var()
 * that way (verified empirically -- it silently no-ops instead of
 * inheriting). An attribute selector always outranks the plain :host rule
 * above on specificity, regardless of source order.
 */
:host([data-cmp-font-inherit]){font-family:inherit;}
*,*::before,*::after{box-sizing:border-box;}
button,input,select,textarea{font:inherit;color:inherit;margin:0;}

.reopen{
  position:fixed;bottom:16px;left:16px;z-index:2147483647;
  background:var(--cmp-primary,#0b1f3a);color:var(--cmp-primary-text,#fff);border:none;border-radius:999px;
  padding:8px 14px;font-size:12px;cursor:pointer;box-shadow:0 2px 8px rgba(0,0,0,.2);
}
.reopen:hover{filter:brightness(0.9);}

/* max-height/overflow: see BANNER SCROLLERS in this file's docblock. */
.bar{
  position:fixed;left:0;right:0;z-index:2147483647;
  background:var(--cmp-surface,#fff);color:var(--cmp-text,#101828);
  padding:16px;box-shadow:0 -2px 12px rgba(0,0,0,.12);
  max-height:85vh;overflow-y:auto;overscroll-behavior:contain;
}
.bar--bottom{bottom:0;border-top:1px solid var(--cmp-border,#d0d5dd);box-shadow:0 -2px 12px rgba(0,0,0,.12);}
.bar--top{top:0;border-bottom:1px solid var(--cmp-border,#d0d5dd);box-shadow:0 2px 12px rgba(0,0,0,.12);}
.bar-inner{max-width:720px;margin:0 auto;display:flex;flex-direction:column;gap:12px;}
.bar-title{font-size:15px;font-weight:600;margin:0;}
.bar-inner p{margin:0;}
.row{display:flex;gap:8px;flex-wrap:wrap;align-items:center;}
.logo{object-fit:contain;}
.logo--small{max-height:20px;max-width:120px;}
.logo--medium{max-height:28px;max-width:160px;}
.logo--large{max-height:40px;max-width:220px;}

/*
 * .box/.cloud + the nine .pos--{y}-{x} modifiers are the banner's own
 * layout/placement system (config.layout/config.position), distinct from
 * .overlay below (the DSR/grievance modal backdrop, always centred).
 * Centring uses margin:auto on a position:fixed box with both opposing
 * offsets set to 0 -- NOT left:50pct;transform:translateX(-50pct). Verified
 * in Chromium: the language switcher's menu (language-switcher.ts) is
 * itself position:fixed with viewport coordinates computed in JS, and it
 * renders as a descendant of this container. A transform on an ancestor
 * becomes the containing block for a position:fixed descendant per the
 * CSS spec, which re-anchors the menu to THIS box instead of the
 * viewport -- measured at 571px off target with translate-based centring.
 * Do not add transform/filter/backdrop-filter/will-change here.
 */
.box,.cloud{
  position:fixed;z-index:2147483647;
  background:var(--cmp-surface,#fff);color:var(--cmp-text,#101828);
  border:1px solid var(--cmp-border,#d0d5dd);border-radius:var(--cmp-radius,8px);
  padding:16px;box-shadow:0 8px 32px rgba(0,0,0,.18);width:calc(100vw - 32px);
  max-height:calc(100vh - 32px);overflow-y:auto;overscroll-behavior:contain;
}
.box{max-width:420px;}
.cloud{max-width:600px;}
.box .bar-inner,.cloud .bar-inner{max-width:none;}
.pos--top-left,.pos--middle-left,.pos--bottom-left{left:16px;}
.pos--top-right,.pos--middle-right,.pos--bottom-right{right:16px;}
.pos--top-center,.pos--middle-center,.pos--bottom-center{left:0;right:0;margin-left:auto;margin-right:auto;}
.pos--top-left,.pos--top-center,.pos--top-right{top:16px;}
.pos--bottom-left,.pos--bottom-center,.pos--bottom-right{bottom:16px;}
.pos--middle-left,.pos--middle-right,.pos--middle-center{top:0;bottom:0;height:fit-content;margin-top:auto;margin-bottom:auto;}

.scrim{position:fixed;inset:0;z-index:2147483646;background:rgba(16,24,40,.45);}

.overlay{
  position:fixed;inset:0;z-index:2147483647;background:rgba(16,24,40,.45);
  display:flex;align-items:center;justify-content:center;padding:16px;
}
/* Flex shell; .panel-body is the only scroller. See PANEL SHELL in this
   file's docblock -- and do NOT add transform/filter/will-change/contain. */
.panel{
  background:var(--cmp-surface,#fff);color:var(--cmp-text,#101828);border-radius:var(--cmp-radius,12px);
  max-width:560px;width:100%;
  max-height:min(86vh,760px);
  display:flex;flex-direction:column;overflow:hidden;overscroll-behavior:contain;
  box-shadow:0 8px 32px rgba(0,0,0,.24);
}
.panel h2{font-size:16px;margin:0 0 8px;}
.panel p{margin:0 0 12px;color:var(--cmp-muted,#475467);}
/* min-height:0 is load-bearing -- see PANEL SHELL in the docblock. */
.panel-body{flex:1 1 auto;min-height:0;overflow-y:auto;overscroll-behavior:contain;padding:16px 20px;}
.panel-footer{
  flex:none;padding:12px 20px 16px;border-top:1px solid var(--cmp-border,#eaecf0);
  background:var(--cmp-surface,#fff);display:flex;flex-direction:column;gap:10px;
}
/* The footer already draws the rule and the gap; don't double them. */
.panel-footer .footer-links{margin-top:0;padding-top:0;border-top:none;}

.bar-head,.panel-header{display:flex;justify-content:flex-end;align-items:center;margin-bottom:8px;}
.panel-header{justify-content:space-between;margin-bottom:0;flex:none;gap:12px;padding:16px 20px 0;}
.panel-header h2{margin:0;}
.bar-head{gap:8px;}

.tab-nav{display:flex;gap:4px;border-bottom:1px solid var(--cmp-border,#eaecf0);flex:none;margin:12px 20px 0;}
.tab-btn{background:none;border:none;border-bottom:2px solid transparent;padding:8px 12px;font-size:13px;cursor:pointer;color:var(--cmp-muted,#475467);}
.tab-btn:hover{color:var(--cmp-text,#101828);}
.tab-btn-active{color:var(--cmp-text,#101828);border-bottom-color:var(--cmp-primary,#0b1f3a);font-weight:600;}
.bar-head--logo-left{justify-content:space-between;}
.lang-switcher{position:relative;}
.lang-toggle{background:none;border:1px solid var(--cmp-border,#d0d5dd);border-radius:6px;padding:4px 10px;font-size:12px;cursor:pointer;color:var(--cmp-text,#101828);}
.lang-menu{position:fixed;background:var(--cmp-surface,#fff);border:1px solid var(--cmp-border,#d0d5dd);border-radius:8px;box-shadow:0 4px 16px rgba(0,0,0,.15);min-width:120px;max-height:min(320px,calc(100vh - 32px));overflow-y:auto;z-index:3;}
.lang-menu-item{display:block;width:100%;text-align:left;background:none;border:none;padding:8px 12px;font-size:13px;cursor:pointer;color:var(--cmp-text,#101828);}
/* A hardcoded near-white hover/active background hid the item's text on a
   dark tenant theme (--cmp-text light-on-dark, hover flipped the row to
   near-white while the text stayed light). rgba(127,127,127,x) is a neutral
   mid-grey tint that reads as a subtle hover on a light surface and a
   subtle lift on a dark one, so text stays legible in both. */
.lang-menu-item:hover{background:rgba(127,127,127,.16);}
.lang-menu-item-active{font-weight:600;background:rgba(127,127,127,.12);}

.cat{border-top:1px solid #eaecf0;padding:12px 0;}
/* .purpose label included for the reason spelled out at the checkbox rule
   below: on the form surfaces a .purpose has no .cat ancestor, so without
   this the label stayed display:inline and the checkbox rendered ABOVE its
   own text instead of beside it. No-op in the prefs panel, where .cat label
   already matches. */
.cat label,.purpose label{display:flex;align-items:flex-start;gap:10px;cursor:pointer;}
/* flex:none because the .cat label rule above makes a flex row, and this rule
   also matches the nested purpose checkboxes, which were being shrunk to
   13-15px against their longer label text — a visibly squashed, slightly oval
   box next to a round category one. A fixed size on a flex item is a request,
   not a floor.

   24x24, not the 16x16 this carried before (ledger 64, WCAG 2.2 SC 2.5.8,
   final review Fix 4). These ARE the consent toggles, so they were the one
   permanent target-size failure the audit would report on every default-theme
   site. Padding on the wrapping .cat label cannot fix it: a11y-audit.ts's
   checkTargetSize measures getBoundingClientRect on the input ITSELF, so only
   the input's own box counts. The two padding-inline-start offsets below
   (.purposes, .purpose-items) track this width plus the label's 10px gap. */
/* .purpose is NOT redundant with .cat: form-view.ts renders .purpose with no
   .cat ancestor, so these same checkboxes were 13x13 there. See the FORM
   surfaces test in preview/a11y-audit.widget.test.ts. */
.cat input[type=checkbox],.purpose input[type=checkbox]{margin-top:2px;width:24px;height:24px;flex:none;}
.cat .cat-text strong{display:block;font-size:13px;}
.cat .cat-text span{display:block;font-size:12px;color:var(--cmp-muted,#475467);margin-top:2px;}
.cat input:disabled + .cat-text,.purpose input:disabled + .purpose-text{opacity:.6;}
/* Collapsed by default (no "open" attribute) — see the docblock in
   preferences-view.ts on why the whole purpose list, not just the
   per-purpose data-items, is now behind a disclosure. */
.cat-purposes{margin-top:8px;}
.cat-purposes>summary{cursor:pointer;color:var(--cmp-text,#101828);font-size:12px;font-weight:500;}
.purposes{list-style:none;margin:8px 0 0;padding-inline-start:34px;display:flex;flex-direction:column;gap:8px;}
.purpose{font-size:12px;}
.purpose strong{display:block;font-size:12px;}
.purpose-desc{display:block;color:var(--cmp-muted,#475467);margin-top:2px;}
.purpose-meta{display:block;color:var(--cmp-muted,#475467);margin-top:2px;font-size:11px;}
/* margin-inline-start matches the label's own checkbox column (24px box +
   10px gap — both track .cat input[type=checkbox] above), so the disclosure
   still lines up under the purpose text now that it sits beside the label
   rather than inside it. */
.purpose-items{margin-top:4px;margin-inline-start:34px;}
.purpose-items>summary{cursor:pointer;color:var(--cmp-muted,#475467);font-size:11px;}
.purpose-items>ul{list-style:none;margin:4px 0 0;padding-inline-start:14px;display:flex;flex-direction:column;gap:3px;}
.purpose-item{font-size:11px;display:flex;gap:6px;align-items:baseline;}
.purpose-item-badge{font-size:10px;padding:1px 5px;border-radius:8px;background:#f2f4f7;color:#475467;white-space:nowrap;}
.purpose-changed{display:inline-block;margin-left:6px;font-size:10px;font-weight:600;padding:1px 6px;border-radius:8px;background:#fffaeb;color:#93370d;white-space:nowrap;vertical-align:middle;}

/* DISCLOSURE CHROME -- see DISCLOSURES in this file's docblock.
   inline-flex here so the chevron sits beside the short label; the two
   Details header rows below push theirs to the far edge instead. */
.cat-purposes>summary,.purpose-items>summary{display:inline-flex;align-items:center;gap:6px;list-style:none;}
.details-cat>summary,.details-provider>summary{display:flex;align-items:center;gap:8px;list-style:none;}
.cat-purposes>summary::-webkit-details-marker,.purpose-items>summary::-webkit-details-marker,
.details-cat>summary::-webkit-details-marker,.details-provider>summary::-webkit-details-marker{display:none;}
.cat-purposes>summary::after,.purpose-items>summary::after,
.details-cat>summary::after,.details-provider>summary::after{
  content:'';flex:none;width:7px;height:7px;
  border-right:2px solid currentColor;border-bottom:2px solid currentColor;
  transform:rotate(45deg);transform-origin:60% 60%;opacity:.55;
}
.details-cat>summary::after,.details-provider>summary::after{margin-inline-start:auto;}
.cat-purposes[open]>summary::after,.purpose-items[open]>summary::after,
.details-cat[open]>summary::after,.details-provider[open]>summary::after{transform:rotate(-135deg);}

/* Neutral tint, not a fixed light fill -- same dark-theme legibility
   reason as .lang-menu-item:hover above. */
.count-badge{
  flex:none;font-size:11px;font-weight:600;padding:1px 7px;border-radius:999px;
  background:rgba(127,127,127,.16);color:var(--cmp-muted,#475467);
}

.details-empty{padding:16px 0;color:var(--cmp-muted,#475467);font-size:13px;}
.details-section{margin-top:16px;padding-top:16px;border-top:1px solid var(--cmp-border,#eaecf0);}
.details-section:first-child{margin-top:0;padding-top:0;border-top:none;}
.details-section h3{font-size:13px;margin:0 0 8px;}
/* Collapsed by default -- details-view.ts sets no "open". */
.details-cat{border-top:1px solid var(--cmp-border,#eaecf0);}
.details-cat:first-of-type{border-top:none;}
.details-cat>summary{cursor:pointer;padding:12px 0;font-size:13px;font-weight:600;color:var(--cmp-text,#101828);}
.details-cat>.details-cat-body{padding:0 0 12px;}
.details-provider{border:1px solid var(--cmp-border,#eaecf0);border-radius:var(--cmp-radius,8px);margin-bottom:8px;}
.details-provider>summary{cursor:pointer;padding:10px 12px;font-size:12px;font-weight:600;color:var(--cmp-text,#101828);}
.details-provider-body{padding:0 12px 12px;}
.details-provider--unnamed>.details-provider-body{padding-top:12px;}
.details-provider-link{display:inline-block;font-size:11px;margin-bottom:8px;}
/* Wide content scrolls in its own box, never widening the panel. */
.details-table-wrap{overflow-x:auto;-webkit-overflow-scrolling:touch;}
.details-table{width:100%;border-collapse:collapse;font-size:12px;}
.details-table th,.details-table td{text-align:start;padding:6px 8px;border-bottom:1px solid var(--cmp-border,#eaecf0);vertical-align:top;}
.details-table th{background:rgba(127,127,127,.08);font-weight:600;}
/* A cookie/script name is one unbreakable token; anywhere+min-width lets a
   data: URI wrap without squeezing ordinary names to "cf_clearan / ce". */
.details-table td:first-child,.details-table th:first-child{min-width:110px;}
.details-table td:first-child{overflow-wrap:anywhere;}
.details-warn{color:#b42318;font-size:11px;margin-top:2px;}
.details-purposes{list-style:none;margin:0;padding:0;display:flex;flex-direction:column;gap:8px;}
.details-purposes li{font-size:12px;padding-inline-start:0;}

.about-section{margin-bottom:16px;}
.about-section h3{font-size:12px;font-weight:600;margin:0 0 4px;color:var(--cmp-muted,#475467);}
.about-section p{margin:0;font-size:13px;}
.about-actions{display:flex;flex-direction:column;gap:10px;margin-top:4px;}
.about-action-desc{margin:2px 0 0;font-size:11px;color:var(--cmp-muted,#475467);}

.btn{
  border:1px solid var(--cmp-border,#d0d5dd);background:var(--cmp-surface,#fff);color:var(--cmp-text,#101828);
  border-radius:var(--cmp-radius,8px);padding:8px 14px;font-size:13px;cursor:pointer;
}
/* :not(.btn-primary) — a bare .btn:hover has higher specificity (0,2,0)
   than .btn-primary's own background rule (0,1,0), so without this
   exclusion a hovered PRIMARY button's background was silently overridden
   to this near-white regardless of theme, while its text stayed
   --cmp-primary-text (typically white) — hiding the CTA's own label on
   hover. .btn-primary:hover below already darkens whatever the real
   --cmp-primary colour is via filter, which is the correct hover for it.
   rgba(127,127,127,x), not a fixed light colour, for the same dark-theme
   text-legibility reason as .lang-menu-item:hover above. */
.btn:not(.btn-primary):hover{background:rgba(127,127,127,.12);}
.btn:disabled{opacity:.5;cursor:default;}
.btn-primary{background:var(--cmp-primary,#0b1f3a);color:var(--cmp-primary-text,#fff);border-color:var(--cmp-primary,#0b1f3a);}
.btn-primary:hover{filter:brightness(0.9);}
.btn-danger{background:#fff;color:#b42318;border-color:#fda29b;}
.btn-danger:hover{background:#fef3f2;}
.btn-link{
  background:none;border:none;color:var(--cmp-primary,#0b1f3a);text-decoration:underline;
  font-size:13px;cursor:pointer;
  /* Ledger 64 (WCAG 2.2 SC 2.5.8): 24x24 minimum. Padding rather than a
     larger font so this stays visually subordinate to Accept/Reject —
     "Manage preferences" and "Withdraw consent" are both .btn-link, and
     banner-view.ts's equal-weight guardrail depends on them not competing. */
  min-height:24px;padding:4px 2px;
}
.btn-link:hover{filter:brightness(0.85);}

.footer-links{display:flex;gap:12px;font-size:12px;margin-top:16px;padding-top:12px;border-top:1px solid #eaecf0;}
.footer-links-item{
  color:var(--cmp-primary,#0b1f3a);text-decoration:underline;cursor:pointer;
  background:none;border:none;font-size:12px;
  /* Same 24px floor as .btn-link above. */
  min-height:24px;padding:6px 2px;
}

/*
 * Ledger 64 (WCAG 2.4.7 / 1.4.11). Nothing defined a focus indicator
 * before this: :host{all:initial} does not remove a UA ring, but it left
 * the ring's colour entirely to the user agent over a tenant-chosen
 * surface — unmeasurable, and low-contrast on dark presets. Themed so it
 * tracks the tenant's own primary, with an offset so it reads against
 * both the button fill and the surface behind it.
 *
 * This selector list must cover EVERY focusable control the widget renders,
 * not just the ones an earlier pass happened to list (final review Fix 3).
 * The first version covered .btn/.btn-link/.footer-links-item plus the
 * .field form controls, which left .reopen (the only control an opt_out
 * visitor ever gets), the .cat consent checkboxes, the panel tabs, the
 * language switcher and the declaration/about anchors with no author-defined
 * indicator at all. a11y-audit.ts's checkFocusIndicator now resolves this
 * list per element (el.matches against each selector here), so a control
 * added without a matching selector reports a real finding instead of
 * riding on any other rule's existence.
 *
 * a[href] is unqualified deliberately: every anchor in this shadow root is
 * ours (about-view.ts's Board-complaint link, details-view.ts's provider
 * privacy-policy links) and none carry a class to hook.
 *
 * .panel-body is in the list because it now carries tabindex="0" — a
 * scrollable region has to be keyboard-reachable or a visitor who cannot use
 * a pointer has no way to scroll the cookie table. That tabindex makes it
 * match a11y-audit.ts's INTERACTIVE selector, and the audit reported the
 * missing indicator as a real finding the first time this shipped without
 * one. Inset rather than offset: an outline drawn OUTSIDE a flex child whose
 * siblings sit flush against it is clipped by the panel's own
 * overflow:hidden, so the ring would be invisible on exactly the element it
 * is meant to mark.
 */
.btn:focus-visible,.btn-link:focus-visible,.footer-links-item:focus-visible,
.field input:focus-visible,.field select:focus-visible,.field textarea:focus-visible,
.reopen:focus-visible,.tab-btn:focus-visible,.lang-toggle:focus-visible,
.lang-menu-item:focus-visible,.cat input[type=checkbox]:focus-visible,
.purpose input[type=checkbox]:focus-visible,
a[href]:focus-visible,summary:focus-visible{
  outline:2px solid var(--cmp-primary,#0b1f3a);
  outline-offset:2px;
}
.panel-body:focus-visible{outline:2px solid var(--cmp-primary,#0b1f3a);outline-offset:-2px;}

.field{margin-bottom:12px;}
.field label{display:block;font-size:12px;font-weight:600;margin-bottom:4px;}
.field input,.field select,.field textarea{
  width:100%;border:1px solid var(--cmp-border,#d0d5dd);border-radius:6px;padding:8px;font-size:13px;
  background:var(--cmp-surface,#fff);color:var(--cmp-text,#101828);
}
.note{font-size:12px;margin-top:8px;}
.note-err{color:#b42318;}
.note-ok{color:#067647;}
/*
 * Themed, not hardcoded: an earlier version fixed this to a literal amber
 * (#fffaeb/#fec84b/#93370d) on the same precedent as .btn-danger's fixed
 * red, but that reads as a foreign sticker dropped onto a rounded/pastel
 * preset like soft-rounded or material-you-ish ones -- a hardcoded 6px-
 * radius cream box next to var(--cmp-radius,16px) panels/buttons is exactly
 * the "same everywhere regardless of design" clash a themed preset exists
 * to avoid. --cmp-primary is already this notice's own accent (the "I am
 * under 18"/footer links inside it use it via .btn-link/.footer-links-item),
 * so borrowing it here keeps the block visually grouped with its own link
 * and lets every preset's border/radius/text tokens apply like everywhere
 * else in this file, rather than introducing a "warning" token no preset
 * defines. Unlike .note-err/.note-ok (colour-only modifiers on an inline
 * .note), .note-warn is a block -- the DPDP s.9 self-declaration notice and
 * the "parental consent pending" status note are both standalone notices,
 * not text appended after other content, so they still need their own
 * border/padding rather than just a text colour.
 */
.note-warn{display:block;border:1.5px solid var(--cmp-primary,#fec84b);border-radius:var(--cmp-radius,6px);padding:10px 12px;color:var(--cmp-text,#101828);}

/* Plain media queries: these only restyle already-rendered markup, so they
   need none of the matchMedia/state.isNarrow path (types.ts). */
@media (max-width:520px){
  .bar-inner{gap:8px;}
  .row{flex-direction:column;align-items:stretch;}
  .row .btn{width:100%;}
  /* .btn-link is not a .btn (components.ts), so the rule above misses it. */
  .row .btn-link{width:100%;text-align:center;}
  .panel-header,.panel-body,.panel-footer{padding-left:16px;padding-right:16px;}
  .tab-nav{margin-left:16px;margin-right:16px;}
  .tab-btn{padding:8px 6px;flex:1 1 0;text-align:center;}

  /* STACKED TABLE -- see NARROW VIEWPORT in this file's docblock. The thead
     is moved off-screen, never display:none'd: it is the real heading. */
  .details-table,.details-table tbody,.details-table tr,.details-table td{display:block;width:100%;}
  .details-table thead{position:absolute;width:1px;height:1px;margin:-1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap;}
  .details-table tr{border-bottom:1px solid var(--cmp-border,#eaecf0);padding:8px 0;}
  .details-table tr:last-child{border-bottom:none;}
  .details-table td{border:none;padding:2px 0;display:flex;gap:8px;align-items:baseline;}
  .details-table td::before{
    content:attr(data-label);flex:none;width:64px;
    color:var(--cmp-muted,#475467);font-weight:600;font-size:11px;
  }
  .details-table td:first-child,.details-table th:first-child{min-width:0;}
  .details-table td:first-child{font-weight:600;}
}
`}function Ke(){let e=document.createElement("compliant-cmp");e.style.setProperty("position","fixed","important"),e.style.setProperty("inset","auto","important"),e.style.setProperty("z-index","2147483647","important"),e.style.setProperty("display","block","important");let t=e.attachShadow({mode:"open"}),o=document.createElement("style");return o.textContent=W(),t.append(o),jt(e),document.body.append(e),t}function jt(e){let t=o=>o.stopPropagation();e.addEventListener("wheel",t,{passive:!0}),e.addEventListener("touchmove",t,{passive:!0})}function ze(e){for(let t of Array.from(e.childNodes))t.nodeName!=="STYLE"&&e.removeChild(t)}function $e(e,t){let o=e.querySelector("style");o&&(o.textContent=t)}var qt=/^#[0-9a-fA-F]{6}$/,Kt=["primary","primaryText","surface","text","muted","border","radius","font"],zt=["primary","primaryText","surface","text","muted","border"],L="'Noto Sans Devanagari','Noto Sans Bengali','Noto Sans Tamil','Noto Sans Telugu','Noto Sans Gujarati','Noto Sans Kannada','Noto Sans Malayalam','Noto Sans Gurmukhi','Noto Sans Oriya'",We={system:`system-ui,-apple-system,"Segoe UI",Roboto,Arial,${L},sans-serif`,geometric:`Poppins,Futura,"Century Gothic",system-ui,${L},sans-serif`,humanist:`"Segoe UI",Calibri,Verdana,system-ui,${L},sans-serif`,serif:`Georgia,"Times New Roman",Times,${L},serif`,slab:`"Rockwell","Roboto Slab",Georgia,${L},serif`,mono:`"SF Mono","Cascadia Code","Roboto Mono",Consolas,${L},monospace`},$t=[...Object.keys(We),"inherit"];function Ye(e){for(let r of Object.keys(e))if(!Kt.includes(r))return null;for(let r of zt){let a=e[r];if(typeof a!="string"||!qt.test(a))return null}let t=e.radius;if(typeof t!="number"||!Number.isInteger(t)||t<0||t>24)return null;let o;if("font"in e){if(typeof e.font!="string"||!$t.includes(e.font))return null;o=e.font}return{primary:e.primary,primaryText:e.primaryText,surface:e.surface,text:e.text,muted:e.muted,border:e.border,radius:t,font:o}}function Je(e){if(!e||Object.keys(e).length===0)return"";let t=Ye(e);if(!t)return"";let o=t.font&&t.font!=="inherit"?`--cmp-font:${We[t.font]};`:"";return`:host{--cmp-primary:${t.primary};--cmp-primary-text:${t.primaryText};--cmp-surface:${t.surface};--cmp-text:${t.text};--cmp-muted:${t.muted};--cmp-border:${t.border};--cmp-radius:${t.radius}px;${o}}`}function Xe(e){return!e||Object.keys(e).length===0?!1:Ye(e)?.font==="inherit"}var Ze=["clinic","allied_health","school","creche","transit","none"],Wt=["health_services","educational_activity","creche_childcare","transport_safety","legal_obligation","child_safety"],et=["already_held_details"],Yt=["adult_self_declared","underage_self_declared","not_collected"];function tt(e){return Ze.includes(e)?e:"none"}var Qe={capable:!1,by:"minor_unverified"};function nt(e){if(e.purpose.essential)return{capable:!0,by:"essential"};if(!Yt.includes(e.ageStatus))return Qe;let t=e.ageStatus==="underage_self_declared";return t&&e.orgFiduciaryClass!=="none"&&Ze.includes(e.orgFiduciaryClass)&&e.purpose.r12ExemptPurpose!==null&&Wt.includes(e.purpose.r12ExemptPurpose)?{capable:!0,by:"r12_exemption",exemptPurpose:e.purpose.r12ExemptPurpose}:e.guardian?.verified===!0?{capable:!0,by:"guardian",means:e.guardian.means}:t&&e.parental?.verified===!0&&e.parental.means!=="virtual_token"&&e.sufficientMeans.includes(e.parental.means)?{capable:!0,by:"parent",means:e.parental.means}:t?Qe:{capable:!0,by:"self"}}function Y(e,t){let o=new Set(t);return(e??[]).filter(r=>r.categories.some(a=>o.has(a)))}function J(e,t,o=null){return{ageStatus:t?.ageStatus??"not_collected",orgFiduciaryClass:tt(e.r12FiduciaryClass),guardian:null,parental:o,sufficientMeans:o?.verified?[o.means]:et}}function X(e,t,o,r,a){if(!nt({purpose:{essential:e.essential,r12ExemptPurpose:e.r12ExemptPurpose??null},...a}).capable)return!1;if(e.essential)return!0;let l=r?.[e.id];if(l!==void 0)return l;let d=e.categories.filter(p=>t.includes(p));return d.length===0?!1:d.every(p=>!!o[p])}var Q=0;function Jt(e,t,o,r){return t||(e==="save_preferences"&&o?o:r?"adult_self_declared":"not_collected")}function Xt(e){return Object.fromEntries(e.map(t=>[t,!0]))}function ge(e){return Object.fromEntries(e.map(t=>[t,t==="necessary"]))}function Qt(e,t,o,r,a){if(!r)return;let i=Y(e,t);if(i.length!==0)return i.map(l=>({purpose_id:l.id,granted:X(l,t,o,r,a)}))}function Zt(e){let t=e.saved;if(!t)return{};let o={...t.purposes??{}};for(let r of e.driftedPurposeIds??[])o[r]=!1;return o}function N(){let e=c(),t=e.config,o=e.saved?.categories??(t?ge(t.categories):{}),r=!e.saved&&t?.geo?.outcome==="opt_out";s({view:"prefs",draft:{...o},draftPurposes:Zt(e),activeTab:"consent",presumedActiveNotice:r})}function R(e,t){let o=c(),r=o.config;if(!r)return;let a;e==="accept_all"?a=Xt(r.categories):e==="reject_non_essential"?a=ge(r.categories):a={...t?.categoriesOverride??{},necessary:!0};let i=Jt(e,t?.ageStatus,o.saved?.ageStatus,r.ageSelfDeclaration),l=J(r,o.saved??void 0,o.parentalCapacity),d=Qt(r.purposes,r.categories,a,t?.purposesOverride,l),p=d?Object.fromEntries(d.map(v=>[v.purpose_id,v.granted])):void 0,y={v:1,action:e,categories:a,at:new Date().toISOString(),ageStatus:i,purposes:p},b=P(y,void 0),w=Ie(b,o.wasReprompted,o.wasReconsent);s({saved:y,view:"hidden",showReopen:!0,wasReprompted:!1,wasReconsent:!1,driftedPurposeIds:[]});let x=++Q;E("/api/v1/consent",{site_key:g.siteKey,visitor_id:_(),action:e,categories:a,purposes:d,language:o.lang,age_status:i,storage_state:w,...o.variant?{variant:o.variant}:{}}).then(v=>{if(!v.ok){console.debug("[cmp.js] consent POST failed (fail-open, UI already updated):",v.error);return}if(x!==Q)return;let S=c().saved;if(!S)return;let I={...S,recordId:v.data.id,...v.data.created_at?{atServer:v.data.created_at}:{}};P(I,void 0),s({saved:I})})}function Z(){let t=c().config;if(!t)return;let r={v:1,action:"withdraw",categories:ge(t.categories),at:new Date().toISOString()},a=Ae(r,void 0),i=++Q;s({saved:r,view:"hidden",showReopen:!0}),E("/api/v1/consent/revoke",{site_key:g.siteKey,visitor_id:_()}).then(l=>{if(!l.ok){console.debug("[cmp.js] revoke POST failed (fail-open, UI already updated):",l.error);return}if(i!==Q)return;let d=c().saved;if(!d)return;let p={...d,recordId:l.data.id,...l.data.created_at?{atServer:l.data.created_at}:{}};P(p,void 0),s({saved:p})})}var en={primary:"btn btn-primary",danger:"btn btn-danger",link:"btn-link"};function m(e,t){let o=t.variant?en[t.variant]:"btn";return n("button",{class:o,type:"button",disabled:!!t.disabled,onClick:t.onClick,...t.attrs},[e])}function B(e,t){return n("button",{class:"footer-links-item",type:"button",onClick:t},[e])}var tn={error:"note note-err",success:"note note-ok",warning:"note note-warn"};function f(e,t){return n("p",{class:tn[e]},[t])}function A(e){let t=u(),o=n("input",{type:"text",inputmode:"numeric",maxlength:"6",name:"code"}),r=n("div",{}),a=m(t.verifyCode,{variant:"primary",onClick:()=>{l()}}),i=n("div",{},[n("p",{},[t.otpPrompt]),n("div",{class:"field"},[n("label",{},[t.verificationCodeLabel]),o]),r,n("div",{class:"row"},[a])]);async function l(){let d=o.value.trim();if(!/^\d{6}$/.test(d)){r.replaceChildren(f("error",t.verifyError));return}a.disabled=!0;let p=await E(e.verifyPath,{site_key:e.siteKey,code:d});if(a.disabled=!1,!p.ok){r.replaceChildren(f("error",t.verifyError));return}e.onVerified()}return i}function ot(){let e=u(),t=n("div",{},[r()]);function o(){t.replaceChildren(...Array.from(fe().childNodes))}function r(){let l=n("input",{type:"email",name:"email"}),d=n("div",{}),p=m(e.ageGateSendCode,{variant:"primary",onClick:()=>{b()}}),y=n("div",{},[n("h2",{},[e.ageGateVerifyTitle]),n("p",{},[e.ageGateVerifyIntro]),n("div",{class:"field"},[n("label",{},[e.email]),l]),d,n("div",{class:"row"},[p])]);async function b(){let w=l.value.trim();if(!w){d.replaceChildren(f("error",e.submitError));return}p.disabled=!0;let x=await E("/api/v1/public/age-gate",{site_key:g.siteKey,email:w});if(p.disabled=!1,!x.ok){o();return}t.replaceChildren(n("h2",{},[e.ageGateVerifyTitle]),A({verifyPath:`/api/v1/public/age-gate/${x.data.id}/verify`,siteKey:g.siteKey,onVerified:()=>t.replaceChildren(a(x.data.id))}))}return y}function a(l){let d=n("input",{type:"date",name:"date_of_birth"}),p=n("div",{}),y=m(e.ageGateContinue,{variant:"primary",onClick:()=>{w()}}),b=n("div",{},[n("h2",{},[e.ageGateVerifyTitle]),n("p",{},[e.ageGateDobIntro]),n("div",{class:"field"},[n("label",{},[e.ageGateDobLabel]),d]),p,n("div",{class:"row"},[y])]);async function w(){let x=d.value.trim();if(!x){p.replaceChildren(f("error",e.submitError));return}y.disabled=!0;let v=await E(`/api/v1/public/age-gate/${l}/age-check`,{site_key:g.siteKey,visitor_id:_(),date_of_birth:x});if(y.disabled=!1,!v.ok){o();return}v.data.is_minor?i(l):N()}return b}function i(l){R("reject_non_essential",{ageStatus:"underage_self_declared"});let d=c().config,p=c().saved;if(d&&p){let y={...p,verificationId:l};P(y,void 0),s({saved:y})}o()}return t}function nn(e){let t=typeof e?.name=="string"?e.name.trim():"",o=typeof e?.email=="string"?e.email.trim():"";return t&&o?{name:t,email:o}:null}function rt(){return c().config?.ageGateVerified?ot():fe()}function fe(){let e=u(),t=c().config,o=nn(t?.dpoOrContact);return n("div",{},[n("h2",{},[e.ageGateTitle]),n("p",{},[e.ageGateBody]),n("p",{},[e.ageGateRestrictionNote]),o?n("p",{},[`${e.ageGateContactLead} ${o.name} (${o.email})`]):null,n("div",{class:"row"},[m(e.ageGateGoBack,{onClick:()=>s({view:"banner"})}),m(e.ageGateIUnderstand,{variant:"primary",onClick:()=>R("reject_non_essential",{ageStatus:"underage_self_declared"})})])])}function ee(){let e=c(),t=e.config;if(!t)return n("span",{});let o=z(t);if(o.length<2)return n("span",{});let r=n("button",{class:"lang-toggle",type:"button","aria-haspopup":"true","aria-expanded":e.langMenuOpen?"true":"false",onClick:i=>{if(i.stopPropagation(),c().langMenuOpen){s({langMenuOpen:!1,langMenuPos:null});return}let l=i.currentTarget.getBoundingClientRect();s({langMenuOpen:!0,langMenuPos:{top:l.bottom+4,right:window.innerWidth-l.right}})}},[G(e.lang)?.nativeName??e.lang]),a=e.langMenuOpen&&e.langMenuPos?n("div",{class:"lang-menu",role:"menu",style:`top:${e.langMenuPos.top}px;right:${e.langMenuPos.right}px;`},o.map(i=>n("button",{class:i===e.lang?"lang-menu-item lang-menu-item-active":"lang-menu-item",type:"button",role:"menuitem",onClick:l=>{l.stopPropagation(),Ue(i)}},[G(i)?.nativeName??i]))):null;return n("div",{class:"lang-switcher"},[r,a])}function on(e){return e==="top"?"top-center":e==="bottom"||!e?"bottom-center":e}var at=520;function it(e,t){let o=t?e?.mobile:void 0;return{layout:o?.layout??e?.layout??"bar",position:on(o?.position??e?.position),overlay:o?.overlay??e?.overlay??!1}}function rn(e,t){let{layout:o,position:r}=it(e,t);return o==="bar"?`bar bar--${r.startsWith("top")?"top":"bottom"}`:`${o} pos--${r}`}function an(e){return e.startsWith("/api/v1/asset/")?`${g.apiBase}${e}`:e}function sn(e){return!!e&&z(e).length>=2}function st(){let e=u(),t=c().config,o=t?.logoUrl,r=o?an(o):null,a=t?.logoPosition??"top-right",i=t?.logoSize??"medium",l=c().isNarrow,d=it(t,l).overlay,p=o&&a==="top-left"?"bar-head bar-head--logo-left":"bar-head";return n("div",{},[d?n("div",{class:"scrim"}):null,n("div",{class:rn(t,l),role:"region","aria-label":e.bannerTitle},[n("div",{class:"bar-inner"},[r||sn(t)?n("div",{class:p},[r?n("img",{class:`logo logo--${a} logo--${i}`,src:r,alt:""}):null,ee()]):null,n("h2",{class:"bar-title"},[e.bannerTitle]),n("p",{},[e.bannerDescription]),t?.ageSelfDeclaration?n("div",{class:"note note-warn"},[n("div",{},[e.ageGateNotice]),B(e.ageGateUnder18Link,()=>s({view:"age_gate"}))]):null,n("div",{class:"row"},[m(e.acceptAll,{variant:"primary",onClick:()=>R("accept_all"),attrs:{"data-cz-consent-accept":""}}),m(e.rejectNonEssential,{variant:"primary",onClick:()=>R("reject_non_essential")}),m(e.managePreferences,{variant:"link",onClick:()=>N()})])])])])}function lt(e,t){if(e==="HTML Local Storage")return{kind:"persistent"};if(e==="HTML Session Storage")return{kind:"session"};if(e!=="HTTP Cookie")return null;if(t===null)return{kind:"not_observed"};if(t<=0)return{kind:"session"};let o=Math.round(t/86400);return o>=365?{kind:"years",count:Math.round(o/365)}:o>=1?{kind:"days",count:o}:t<3600?{kind:"less_than_hour"}:{kind:"hours",count:Math.round(t/3600)}}function ct(e,t){if(t===null)return null;switch(t.kind){case"persistent":return e.declarationRetentionPersistent;case"session":return e.declarationRetentionSession;case"not_observed":return e.declarationRetentionNotObserved;case"less_than_hour":return e.declarationRetentionLessThanHour;case"hours":return t.count===1?e.declarationRetentionHour:e.declarationRetentionHoursPlural.replace("{count}",String(t.count));case"days":return t.count===1?e.declarationRetentionDay:e.declarationRetentionDaysPlural.replace("{count}",String(t.count));case"years":return t.count===1?e.declarationRetentionYear:e.declarationRetentionYearsPlural.replace("{count}",String(t.count))}}var dt=["access","correction","erasure","nomination","withdrawal"],pt=["consent_handling","data_accuracy","erasure_delay","unsolicited_communication","data_breach","unauthorised_processing","rights_not_honoured","excessive_collection","retention_violation","third_party_sharing","childrens_data_misuse","cross_border_transfer","other"];function te(e,t){return n("div",{class:"field"},[n("label",{},[e]),t])}function ut(){let e=u(),t=n("select",{name:"request_type"},dt.map(b=>n("option",{value:b},[e.requestTypeLabels[b]??b]))),o=n("input",{type:"text",name:"full_name"}),r=n("input",{type:"email",name:"email"}),a=n("textarea",{name:"description",rows:"3"}),i=n("div",{}),l=m(e.submit,{variant:"primary",onClick:()=>{p()}}),d=n("div",{},[n("h2",{},[e.submitDataRequest]),te(e.requestType,t),te(e.fullName,o),te(e.email,r),te(e.description,a),i,n("div",{class:"row"},[l,m(e.backToPreferences,{onClick:()=>s({view:"prefs"})})])]);async function p(){let b=o.value.trim(),w=r.value.trim(),x=a.value.trim(),v=t.value;if(!b||!w){i.replaceChildren(f("error",e.submitError));return}l.disabled=!0;let S=await E("/api/v1/dsr",{site_key:g.siteKey,request_type:v,full_name:b,email:w,description:x||void 0});if(l.disabled=!1,!S.ok){i.replaceChildren(f("error",e.submitError));return}if(S.data.verification_required){d.replaceChildren(n("h2",{},[e.submitDataRequest]),A({verifyPath:`/api/v1/dsr/${S.data.id}/verify`,siteKey:g.siteKey,onVerified:()=>y()}));return}y()}function y(){d.replaceChildren(n("h2",{},[e.submitDataRequest]),f("success",e.submitSuccessDsr),n("div",{class:"row"},[m(e.backToPreferences,{onClick:()=>s({view:"prefs"})})]))}return d}function ne(e,t){return n("div",{class:"field"},[n("label",{},[e]),t])}function mt(){let e=u(),t=n("select",{name:"category"},pt.map(b=>n("option",{value:b},[e.grievanceCategoryLabels[b]??b]))),o=n("input",{type:"text",name:"full_name"}),r=n("input",{type:"email",name:"email"}),a=n("textarea",{name:"description",rows:"3"}),i=n("div",{}),l=m(e.submit,{variant:"primary",onClick:()=>{p()}}),d=n("div",{},[n("h2",{},[e.fileGrievance]),ne(e.category,t),ne(e.fullName,o),ne(e.email,r),ne(e.description,a),i,n("div",{class:"row"},[l,m(e.backToPreferences,{onClick:()=>s({view:"prefs"})})])]);async function p(){let b=o.value.trim(),w=r.value.trim(),x=a.value.trim(),v=t.value;if(!b||!w||!x){i.replaceChildren(f("error",e.submitError));return}l.disabled=!0;let S=await E("/api/v1/grievance",{site_key:g.siteKey,category:v,full_name:b,email:w,description:x});if(l.disabled=!1,!S.ok){i.replaceChildren(f("error",e.submitError));return}if(S.data.verification_required){d.replaceChildren(n("h2",{},[e.fileGrievance]),A({verifyPath:`/api/v1/grievance/${S.data.id}/verify`,siteKey:g.siteKey,onVerified:()=>y()}));return}y()}function y(){d.replaceChildren(n("h2",{},[e.fileGrievance]),f("success",e.submitSuccessGrievance),n("div",{class:"row"},[m(e.backToPreferences,{onClick:()=>s({view:"prefs"})})]))}return d}function ln(e){return typeof AbortSignal<"u"&&typeof AbortSignal.timeout=="function"?AbortSignal.timeout(e):void 0}async function gt(){s({historyStatus:"submitting"});try{let e=await fetch(`${g.apiBase}/api/v1/consent/export`,{method:"POST",mode:"cors",credentials:"omit",headers:{"content-type":"application/json"},body:JSON.stringify({site_key:g.siteKey,visitor_id:_(),format:"json"}),signal:ln(8e3)});if(!e.ok)throw new Error("http");let t=await e.blob(),o=URL.createObjectURL(t),r=document.createElement("a");r.href=o,r.download=`consent-history-${new Date().toISOString().slice(0,10)}.json`,document.body.append(r),r.click(),r.remove(),URL.revokeObjectURL(o),s({historyStatus:"idle"})}catch{s({historyStatus:"error"})}}function cn(e){return typeof AbortSignal<"u"&&typeof AbortSignal.timeout=="function"?AbortSignal.timeout(e):void 0}async function ft(){let t=c().saved;if(t){if(!t.recordId){s({receiptStatus:"error"});return}s({receiptStatus:"submitting"});try{let o=await fetch(`${g.apiBase}/api/v1/consent/receipt`,{method:"POST",mode:"cors",credentials:"omit",headers:{"content-type":"application/json"},body:JSON.stringify({site_key:g.siteKey,record_id:t.recordId}),signal:cn(15e3)});if(!o.ok)throw new Error("http");let r=await o.blob(),a=URL.createObjectURL(r),i=document.createElement("a");i.href=a,i.download=`consent-receipt-${t.at.slice(0,10)}.pdf`,document.body.append(i),i.click(),i.remove(),URL.revokeObjectURL(a),s({receiptStatus:"idle"})}catch{s({receiptStatus:"error"})}}}function oe(){let e=c().declarationStatus;e==="loading"||e==="success"||e==="error"||e==="not_published"||(s({declarationStatus:"loading"}),Te(`/api/v1/cookie-declaration/${encodeURIComponent(g.siteKey)}?lang=${encodeURIComponent(c().lang)}`).then(t=>{t.ok?s({declaration:t.data,declarationStatus:"success"}):t.error==="http"&&t.status===404?s({declarationStatus:"not_published"}):s({declarationStatus:"error"})}))}function dn(e,t){if(!e)return"—";let o=new Date(e);if(Number.isNaN(o.getTime()))return"—";try{return o.toLocaleDateString(t)}catch{return o.toLocaleDateString()}}function bt(){oe();let e=c(),t=e.config;if(!t)return n("div",{});let o=u(),r=t.orgName,a=t.dpoOrContact??{},i=t.noticeContent??{},l=e.declarationStatus==="success"&&e.declaration?o.aboutDeclarationVersion.replace("{version}",String(e.declaration.version)).replace("{date}",dn(e.declaration.publishedAt,e.lang)):e.declarationStatus==="loading"||e.declarationStatus==="idle"?o.declarationLoading:o.declarationEmptyState;return n("div",{},[r?n("div",{class:"about-section about-controller"},[n("h3",{},[o.aboutDataController]),n("p",{},[r])]):null,a.name||a.email?n("div",{class:"about-section"},[n("h3",{},[o.aboutDpo]),n("p",{},[[a.name,a.email].filter(Boolean).join(" · ")])]):null,i.purpose?n("div",{class:"about-section"},[n("h3",{},[o.aboutPurpose]),n("p",{},[i.purpose])]):null,n("div",{class:"about-section"},[n("h3",{},[o.aboutLinks]),n("div",{class:"about-actions"},[n("div",{class:"about-action"},[t.revokeEnabled&&e.saved?m(o.withdrawConsent,{variant:"link",onClick:()=>Z()}):null,i.withdrawalRoute?n("p",{class:"about-action-desc"},[i.withdrawalRoute]):null]),n("div",{class:"about-action"},[t.dsrEnabled?m(o.aboutExerciseRights,{variant:"link",onClick:()=>s({view:"dsr"})}):null,i.rightsRoute?n("p",{class:"about-action-desc"},[i.rightsRoute]):null]),n("div",{class:"about-action"},[/^https?:\/\//i.test(i.boardComplaintUrl??"")?n("a",{href:i.boardComplaintUrl,"data-board-complaint":"true"},[o.aboutBoardComplaintLink]):null,i.boardComplaintRoute?n("p",{class:"about-action-desc"},[i.boardComplaintRoute]):null])])]),n("div",{class:"about-section"},[n("h3",{},[o.aboutDeclaration]),n("p",{},[l])])])}var pn={necessary:"Necessary",functional:"Functional",analytics:"Analytics",communications:"Communications",marketing:"Marketing",unclassified:"Not yet classified"};function un(e,t){let o=u();return e==="unclassified"?o.declarationUnclassifiedLabel:(t==="en"?void 0:O(t)?.categories[e])?.label??pn[e]??e}function mn(e){let t=u(),o=t.declarationTypeLabels[e.type]??e.type,r=ct(t,lt(e.type,e.maxAgeSeconds)),a=e.hostCount>1?`${e.name??e.type} [×${e.hostCount}]`:e.name??e.type;return n("tr",{},[n("td",{"data-label":t.declarationColumnName},[a,e.firedPreConsent?n("div",{class:"details-warn"},[t.declarationPreConsentWarning]):null]),n("td",{"data-label":t.declarationColumnType},[o]),n("td",{"data-label":t.declarationColumnPurpose},[e.purposeText??"—"]),n("td",{"data-label":t.declarationColumnRetention},[r??"—"])])}function yt(e){let t=u();return n("div",{class:"details-table-wrap"},[n("table",{class:"details-table"},[n("thead",{},[n("tr",{},[n("th",{},[t.declarationColumnName]),n("th",{},[t.declarationColumnType]),n("th",{},[t.declarationColumnPurpose]),n("th",{},[t.declarationColumnRetention])])]),n("tbody",{},e.map(mn))])])}function gn(e){let t=u();return n("details",{class:"details-provider"},[n("summary",{},[n("span",{class:"details-provider-name"},[e.name]),n("span",{class:"count-badge"},[String(e.entries.length)])]),n("div",{class:"details-provider-body"},[e.privacyUrl?n("a",{class:"details-provider-link",href:e.privacyUrl,target:"_blank",rel:"noopener noreferrer"},[t.declarationPrivacyPolicyLink]):null,yt(e.entries)])])}function fn(e){return n("div",{class:"details-provider details-provider--unnamed"},[n("div",{class:"details-provider-body"},[yt(e.entries)])])}function bn(e){return e.name.trim()?gn(e):fn(e)}function ht(){oe();let e=c(),t=u();if(e.declarationStatus==="idle"||e.declarationStatus==="loading")return n("div",{},[n("p",{class:"details-empty"},[t.declarationLoading])]);if(e.declarationStatus==="error")return n("div",{},[f("error",t.declarationLoadError)]);if(e.declarationStatus==="not_published")return n("div",{},[n("p",{class:"details-empty"},[t.declarationEmptyState])]);let o=e.declaration,r=o?.schemaVersion===2?o.categories:[];if(r.length===0)return n("div",{},[n("p",{class:"details-empty"},[t.declarationEmptyState])]);let a=r.map(i=>n("details",{class:"details-cat"},[n("summary",{},[n("span",{},[un(i.category,e.lang)]),n("span",{class:"count-badge"},[String(i.count)])]),n("div",{class:"details-cat-body"},i.providers.map(bn))]));return n("div",{},a)}var yn={consent:"lawfulBasisConsent",legitimate_use:"lawfulBasisLegitimateUse",voluntary:"lawfulBasisVoluntary"};function hn(){let e=c(),t=e.config;if(!t)return n("div",{});let o=u(),r=e.saved?.ageStatus==="underage_self_declared",a=J(t,e.saved??void 0,e.parentalCapacity),i=Y(t.purposes,t.categories),l=t.categories.map(p=>{let y=p==="necessary",b=y?!0:r?!1:!!e.draft[p],{label:w,description:x}=je(p,t.bannerText,e.lang),v=n("input",{type:"checkbox",checked:b,disabled:y||r,onChange:h=>{let re=h.target;s({draft:{...c().draft,[p]:re.checked}})}}),S=i.filter(h=>h.categories.includes(p)),I=S.length===0?null:n("ul",{class:"purposes"},S.map(h=>{let re=X(h,t.categories,e.draft,e.draftPurposes,a),Pt=(e.driftedPurposeIds??[]).includes(h.id),Lt=h.lawfulBasis!=="legitimate_use"?n("input",{type:"checkbox",checked:re,disabled:h.essential||r,onChange:T=>{let we=T.target;s({draftPurposes:{...c().draftPurposes,[h.id]:we.checked}})}}):null;return n("li",{class:"purpose"},[n("label",{},[Lt,n("div",{class:"purpose-text"},[n("strong",{},[h.name]),Pt?n("span",{class:"purpose-changed"},[o.purposeChanged]):null,h.description?n("span",{class:"purpose-desc"},[h.description]):null,n("span",{class:"purpose-meta"},[o.purposeRetention.replace("{days}",String(h.retentionDays))]),n("span",{class:"purpose-meta"},[o.purposeBasis.replace("{basis}",(()=>{let T=yn[h.lawfulBasis];return(T?o[T]:void 0)||h.lawfulBasis})())])])]),h.dataItems&&h.dataItems.length>0?n("details",{class:"purpose-items"},[n("summary",{},[o.purposeDataItems.replace("{count}",String(h.dataItems.length))]),n("ul",{},h.dataItems.map(T=>n("li",{class:"purpose-item"},[n("span",{class:"purpose-item-name"},[T.name]),T.sensitivity?n("span",{class:"purpose-item-badge"},[o.sensitivityLabels[T.sensitivity]??T.sensitivity]):null])))]):null])}));return n("div",{class:"cat"},[n("label",{},[v,n("div",{class:"cat-text"},[n("strong",{},[w]),n("span",{},[x])])]),I?n("details",{class:"cat-purposes"},[n("summary",{},[o.categoryPurposesToggle.replace("{count}",String(S.length))]),I]):null])}),d=e.saved?.action==="withdraw";return n("div",{},[d?f("success",o.withdrawnNotice):null,e.gpcNotice?f("success",o.gpcNotice):null,e.presumedActiveNotice?f("warning",o.presumedActiveNotice):null,r?n("div",{class:"note note-warn"},[n("strong",{},[o.ageGateRestrictedStatus]),n("div",{},[o.ageGatePendingNote])]):null,...l,n("p",{class:"note"},[o.renewalNotice.replace("{days}",String(t.consentValidityDays))])])}function vn(){let e=c(),t=e.config;if(!t)return n("div",{class:"panel-footer"},[]);let o=u(),r=e.saved?.ageStatus==="underage_self_declared",a=t.revokeEnabled&&!!e.saved,i=!!e.saved,l=r?[]:[m(o.rejectNonEssential,{variant:"primary",onClick:()=>R("reject_non_essential")}),m(o.savePreferences,{variant:"primary",onClick:()=>R("save_preferences",{categoriesOverride:c().draft,purposesOverride:c().draftPurposes})}),m(o.acceptAll,{variant:"primary",onClick:()=>R("accept_all")})];return n("div",{class:"panel-footer"},[l.length>0?n("div",{class:"row row--actions"},l):null,a||i?n("div",{class:"row row--secondary"},[a?m(o.withdrawConsent,{variant:"danger",onClick:()=>Z()}):null,i?m(o.downloadReceipt,{disabled:e.receiptStatus==="submitting",onClick:()=>{ft()}}):null,i?m(o.downloadHistory,{disabled:e.historyStatus==="submitting",onClick:()=>{gt()}}):null]):null,e.receiptStatus==="error"?f("error",o.receiptError):null,e.historyStatus==="error"?f("error",o.historyError):null,t.dsrEnabled||t.grievanceEnabled?n("div",{class:"footer-links"},[t.dsrEnabled?B(o.submitDataRequest,()=>s({view:"dsr"})):null,t.grievanceEnabled?B(o.fileGrievance,()=>s({view:"grievance"})):null]):null])}var D=["consent","details","about"];function be(e,t,o){return n("button",{class:o?"tab-btn tab-btn-active":"tab-btn",type:"button",role:"tab",id:`cmp-tab-${e}`,"aria-selected":o?"true":"false","aria-controls":"cmp-tabpanel",tabindex:o?"0":"-1","data-tab":e,onClick:()=>s({activeTab:e}),onKeydown:r=>{let a=r.key,i=D.indexOf(e),l=a==="ArrowRight"?(i+1)%D.length:a==="ArrowLeft"?(i-1+D.length)%D.length:a==="Home"?0:a==="End"?D.length-1:-1;if(l<0)return;r.preventDefault();let d=D[l],p=r.currentTarget.getRootNode();s({activeTab:d}),p.querySelector(`[data-tab="${d}"]`)?.focus()}},[t])}function vt(){let e=c();if(!e.config)return n("div",{});let t=u(),o=e.activeTab,r=o==="details"?ht():o==="about"?bt():hn();return n("div",{class:"overlay"},[n("div",{class:"panel",role:"dialog","aria-modal":"true","aria-label":t.managePreferences},[n("div",{class:"panel-header"},[n("h2",{},[t.managePreferences]),ee()]),n("div",{class:"tab-nav",role:"tablist","aria-label":t.managePreferences},[be("consent",t.tabConsent,o==="consent"),be("details",t.tabDetails,o==="details"),be("about",t.tabAbout,o==="about")]),n("div",{class:"panel-body",id:"cmp-tabpanel",role:"tabpanel","aria-labelledby":`cmp-tab-${o}`,tabindex:"0"},[r]),vn()])])}function xt(){let e=u();return n("button",{class:"reopen",type:"button","aria-label":e.reopenLabel,onClick:()=>N()},[e.reopenLabel])}function ye(e,t){return n("div",{class:"overlay"},[n("div",{class:"panel",role:"dialog","aria-modal":"true","aria-label":e},[n("div",{class:"panel-body"},[t])])])}var xn=new Set(["prefs","dsr","grievance","age_gate"]),he=!1,ve=!1;function wt(e){if(he){ve=!0;return}he=!0;let t=e.activeElement?.id||null;try{do ve=!1,wn(e);while(ve)}finally{he=!1}t&&e.activeElement===null&&e.querySelector(`[id="${t}"]`)?.focus()}function wn(e){let t=c();if(ze(e),t.configFailed){V(!1);return}if(!t.config){V(!1);return}if(!qe(t.config)){V(!1),console.warn("[cmp.js] this host is not registered for this site; widget will not render.");return}if(V(xn.has(t.view)),$e(e,W()+Je(t.config.theme)),e.host.toggleAttribute("data-cmp-font-inherit",Xe(t.config.theme)),e.host.setAttribute("dir",G(t.lang)?.textDirection??"ltr"),e.host.setAttribute("lang",t.lang),t.view==="hidden"){t.showReopen&&e.append(xt());return}if(t.view==="banner"){e.append(st());return}if(t.view==="prefs"){e.append(vt());return}if(t.view==="age_gate"){e.append(ye(u().ageGateTitle,rt()));return}if(t.view==="dsr"){e.append(ye(u().submitDataRequest,ut()));return}if(t.view==="grievance"){e.append(ye(u().fileGrievance,mt()));return}}function St(e,t){return t<=0?!0:Date.now()-new Date(e.at).getTime()>t*864e5}function Ct(e,t){let o=e.atServer??e.at;return(t??[]).filter(r=>r.materialSince!==void 0&&o<r.materialSince).map(r=>r.id)}function Et(){if(!(typeof window>"u"||typeof window.matchMedia!="function"))try{let e=window.matchMedia(`(max-width:${at}px)`);s({isNarrow:e.matches}),e.addEventListener("change",t=>s({isNarrow:t.matches}))}catch{}}var _t=performance.now(),M=null,xe=null,Rt=null,kt=!1;Ee(e=>{switch(e.type){case"init":Sn(e);return;case"view":M?s({view:e.view}):C({type:"error",message:"view requested before init"});return;case"catalog":_e(e);return;case"httpResult":ke(e);return}});function Sn(e){if(M)return;Et(),Pe({siteKey:e.siteKey,apiBase:e.apiBase}),Le({visitorId:e.visitorId,prefs:e.prefs,lang:e.lang}),C({type:"ready",timeToReadyMs:performance.now()-_t});let t=Ne(),o=t?St(t,e.config.consentValidityDays):!1,r=t&&!o?Ct(t,e.config.purposes):[],a=r.length>0,i=o?null:t;M=Ke(),xe=i,s({config:e.config,lang:Be(e.config),saved:i,view:!i||a?"banner":"hidden",showReopen:!1,wasReprompted:o,driftedPurposeIds:a?r:void 0,wasReconsent:a}),i||(Ge(e.config),s({showReopen:!1})),t?.ageStatus==="underage_self_declared"&&t.verificationId&&E("/api/v1/public/age-gate/capacity",{site_key:e.siteKey,verification_id:t.verificationId}).then(d=>{let p=d.ok&&d.data.capable&&d.data.by==="parent"&&d.data.means?{verified:!0,means:d.data.means}:null;s({parentalCapacity:p})});let l=c().lang;l!=="en"&&F(l,()=>s({lang:c().lang})),document.addEventListener("click",()=>{c().langMenuOpen&&s({langMenuOpen:!1})}),He(Tt),Tt()}function Tt(){if(!M)return;wt(M);let e=c();if(e.saved!==xe&&(xe=e.saved,e.saved&&C({type:"decision",prefs:e.saved,signals:Se(e.saved.categories)})),e.view!==Rt&&(Rt=e.view,C({type:"viewChanged",view:e.view})),!kt&&e.view!=="hidden"){kt=!0;let t=M;requestAnimationFrame(()=>{requestAnimationFrame(()=>{t.host.isConnected&&C({type:"painted",timeToPaintMs:performance.now()-_t})})})}}})();
