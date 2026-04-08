import { useState, useEffect, useRef } from 'react'
import { GoogleLogin, useGoogleLogin } from '@react-oauth/google'
import { Camera, Upload, LogOut, CheckCircle2, ChevronDown, Check } from 'lucide-react'

// Production: Cloud Run backend. Dev: localhost.
const API_BASE = import.meta.env.DEV
  ? 'http://localhost:8080/api'
  : 'https://expense-api-253025248502.europe-west6.run.app/api'

export default function App() {
  const [auth, setAuth] = useState(null)
  const [employee, setEmployee] = useState(null)
  const [activeTab, setActiveTab] = useState('capture')
  
  // Try to load auth from localStorage
  useEffect(() => {
    const saved = localStorage.getItem('expense_auth')
    if (saved) {
      try {
        setAuth(JSON.parse(saved))
      } catch(e) {}
    }
  }, [])

  // When auth changes, fetch user profile
  useEffect(() => {
    if (auth?.token) {
      console.log('[EF] Fetching employee profile from:', `${API_BASE}/employee/me`)
      fetch(`${API_BASE}/employee/me`, {
        headers: { Authorization: `Bearer ${auth.token}` }
      })
      .then(r => {
        console.log('[EF] /employee/me response status:', r.status)
        if (r.status === 401) {
          // Only logout if the server explicitly says token is invalid
          console.warn('[EF] Token rejected by server (401) — logging out')
          handleLogout()
          return null
        }
        return r.json()
      })
      .then(data => {
        if (!data) return // already handled above
        console.log('[EF] Employee data:', data)
        setEmployee(data.error ? { email: 'unknown', EmployeeName: 'User' } : data)
      })
      .catch(err => {
        console.error('[EF] Network error fetching /employee/me:', err)
        // Do NOT logout on network errors — just set a fallback employee
        setEmployee({ email: 'unknown', EmployeeName: 'User' })
      })
    }
  }, [auth])

  const handleLoginSuccess = (credentialResponse) => {
    const token = credentialResponse.credential
    const authData = { token }
    localStorage.setItem('expense_auth', JSON.stringify(authData))
    setAuth(authData)
  }

  const handleLogout = () => {
    localStorage.removeItem('expense_auth')
    setAuth(null)
    setEmployee(null)
  }

  if (!auth) {
    return <LoginScreen onSuccess={handleLoginSuccess} />
  }

  return (
    <div className="app-container">
      <nav className="navbar">
        <div style={{fontWeight:600}}>EF Expenses</div>
        {employee && (
          <div style={{display:'flex', gap:'12px', alignItems:'center'}}>
            <span style={{fontSize:'0.85rem', color:'var(--text-muted)'}}>
              {employee.EmployeeName}
            </span>
            <button 
              onClick={handleLogout}
              style={{background:'none', border:'none', color:'var(--text-muted)', cursor:'pointer'}}
            >
              <LogOut size={18}/>
            </button>
          </div>
        )}
      </nav>
      
      <div className="tabs-container">
        <button 
          className={`tab-btn ${activeTab === 'capture' ? 'active' : ''}`}
          onClick={() => setActiveTab('capture')}
        >
          Capture Receipt
        </button>
        <button 
          className={`tab-btn ${activeTab === 'ledger' ? 'active' : ''}`}
          onClick={() => setActiveTab('ledger')}
        >
          My Accounts
        </button>
      </div>

      {activeTab === 'capture' && <ExpenseForm auth={auth} employee={employee} />}
      {activeTab === 'ledger' && <LedgerTab auth={auth} employee={employee} />}
    </div>
  )
}

function LedgerTab({ auth, employee }) {
  const [data, setData] = useState({ accounts: [], transactions: [], invoices: [] })
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    fetch(`${API_BASE}/employee/ledger`, {
       headers: { Authorization: `Bearer ${auth.token}` }
    })
    .then(r => r.json())
    .then(d => {
       setData({
         accounts: d.accounts || [],
         transactions: d.transactions || [],
         invoices: d.invoices || []
       })
       setLoading(false)
    })
    .catch(err => {
      console.error(err)
      setLoading(false)
    })
  }, [auth])

  if (loading) return <div style={{padding:'40px 20px', textAlign:'center', color:'var(--text-muted)'}}>Loading accounts...</div>

  const { accounts, transactions, invoices } = data

  return (
    <div className="ledger-section animate-enter">
      {accounts.length === 0 ? (
        <div style={{textAlign: 'center', padding:'40px 20px', color:'var(--text-muted)'}}>
          <p>No accounts found for your profile.</p>
        </div>
      ) : accounts.map(acc => {
         const accTxs = transactions.filter(t => t.OriginAccount === acc.id || t.DestinationAccount === acc.id)
         const accInvs = invoices.filter(i => i.OriginAccount === acc.id || i.DestinationAccount === acc.id)
         
         const events = [...accTxs.map(t => ({...t, eventType: 'tx'})), ...accInvs.map(i => ({...i, eventType: 'inv'}))]
         events.sort((a,b) => new Date(b.Date || b.SentDate) - new Date(a.Date || a.SentDate))

         return (
           <div key={acc.id} className="account-card">
              <div className="account-header">
                <div>{acc.Name}</div>
                <div style={{fontSize:'0.8rem', color:'var(--text-muted)'}}>{acc.CurrencyCode}</div>
              </div>
              
              <div className="tx-list">
                {events.length === 0 ? (
                  <div style={{fontSize:'0.85rem', color:'var(--text-muted)', fontStyle:'italic', padding:'8px 0'}}>
                    No activity in the last 6 months
                  </div>
                ) : events.map(ev => {
                  const isPositive = ev.DestinationAccount === acc.id
                  const isTx = ev.eventType === 'tx'
                  const date = ev.Date || ev.SentDate
                  const textAmount = isPositive ? `+${ev.Amount}` : `-${ev.Amount}`
                  
                  return (
                    <div key={ev.eventType + '_' + ev.id} className="tx-item">
                      <div className="tx-item-left">
                        <div className="tx-desc" title={ev.Description}>{ev.Description || (isTx ? 'Transaction' : 'Invoice')}</div>
                        <div className="tx-date">{new Date(date).toLocaleDateString()}</div>
                      </div>
                      <div className="tx-item-right">
                        <div className={`tx-amount ${isPositive ? 'positive' : 'negative'}`}>
                          {textAmount}
                        </div>
                        {!isTx && (
                          <div className={`tx-status ${(ev.Status || '').toLowerCase()}`}>
                            {ev.Status}
                          </div>
                        )}
                      </div>
                    </div>
                  )
                })}
              </div>
           </div>
         )
      })}
    </div>
  )
}

function LoginScreen({ onSuccess }) {
  return (
    <div style={{display: 'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', minHeight:'100vh', padding:'24px'}}>
      <div className="glass-panel" style={{textAlign:'center', width:'100%', maxWidth:'400px'}}>
        <div style={{width:'64px', height:'64px', background:'var(--accent)', borderRadius:'16px', margin:'0 auto 24px', display:'flex', alignItems:'center', justifyContent:'center'}}>
          <Camera size={32} color="white"/>
        </div>
        <h1>Expertflow Expenses</h1>
        <p style={{marginBottom:'32px'}}>Sign in with your @expertflow.com account to capture receipts.</p>
        
        <div style={{display:'flex', justifyContent:'center'}}>
          <GoogleLogin
            onSuccess={onSuccess}
            onError={() => { console.log('Login Failed') }}
            hosted_domain="expertflow.com"
          />
        </div>
      </div>
    </div>
  )
}

function ExpenseForm({ auth, employee }) {
  const [type, setType] = useState('invoice') // invoice (Out of Pocket) | transaction (Company Card)
  const [file, setFile] = useState(null)
  const [preview, setPreview] = useState(null)
  
  // Form data
  const [amount, setAmount] = useState('')
  const [currency, setCurrency] = useState('')
  const [project, setProject] = useState('')
  const [account, setAccount] = useState('')
  const [desc, setDesc] = useState('')
  
  // Lookups
  const [currencies, setCurrencies] = useState([])
  const [projects, setProjects] = useState([])
  const [accounts, setAccounts] = useState([])
  
  const [submitting, setSubmitting] = useState(false)
  const [success, setSuccess] = useState(null)
  const [error, setError] = useState(null)
  
  const fileInputRef = useRef(null)

  // Load lookups
  useEffect(() => {
    if (!auth?.token) return
    const headers = { Authorization: `Bearer ${auth.token}` }
    
    Promise.all([
      fetch(`${API_BASE}/currencies`, { headers }).then(r=>r.json()),
      fetch(`${API_BASE}/projects`, { headers }).then(r=>r.json()),
      fetch(`${API_BASE}/accounts`, { headers }).then(r=>r.json()),
    ]).then(([curData, projData, accData]) => {
      if(!curData.error) setCurrencies(curData)
      if(!projData.error) {
        setProjects(projData)
        // Default project
        if (employee?.DefaultProjectId) {
          setProject(employee.DefaultProjectId.toString())
        }
      }
      if(!accData.error) setAccounts(accData)
    })
  }, [auth, employee])

  const handleCapture = (e) => {
    if (e.target.files && e.target.files[0]) {
      const selectedFile = e.target.files[0]
      setFile(selectedFile)
      setPreview(URL.createObjectURL(selectedFile))
    }
  }

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!file) {
      setError('Please capture or upload a receipt')
      return;
    }
    
    setSubmitting(true)
    setError(null)
    
    const formData = new FormData()
    formData.append('receipt', file)
    formData.append('type', type)
    formData.append('amount', amount)
    if (type !== 'invoice') {
      formData.append('currency_id', currency)
    }
    formData.append('project_id', project)
    formData.append('description', desc)
    if (type === 'transaction') {
      formData.append('account_id', account)
    }

    try {
      const res = await fetch(`${API_BASE}/submit`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${auth.token}` },
        body: formData
      })
      const data = await res.json()
      
      if (!res.ok) throw new Error(data.error || 'Submission failed')
      
      setSuccess(data.data)
      // Reset form
      setFile(null); setPreview(null); setAmount(''); setDesc('');
    } catch(err) {
      setError(err.message)
    } finally {
      setSubmitting(false)
    }
  }

  if (success) {
    return (
      <div className="glass-panel animate-enter" style={{margin:'24px', textAlign:'center'}}>
        <CheckCircle2 color="var(--success)" size={48} style={{margin:'0 auto 16px'}} />
        <h2>Receipt Captured!</h2>
        <p style={{marginBottom:'24px'}}>
          Created {success.type} #{success.id}.<br/>
          Image uploaded to GDrive.
        </p>
        <button className="btn" onClick={() => setSuccess(null)}>
          Capture Another
        </button>
      </div>
    )
  }

  return (
    <div style={{padding:'20px'}}>
      
      <div className="type-toggle">
        <button 
          className={type==='invoice'?'active':''} 
          onClick={()=>setType('invoice')}
        >
          Out of Pocket
        </button>
        <button 
          className={type==='transaction'?'active':''} 
          onClick={()=>setType('transaction')}
        >
          Company Card
        </button>
      </div>

      <form onSubmit={handleSubmit} className="glass-panel animate-enter">
        {error && (
          <div style={{background:'rgba(239,68,68,0.1)', color:'var(--error)', padding:'12px', borderRadius:'8px', marginBottom:'16px', fontSize:'0.875rem'}}>
            {error}
          </div>
        )}

        {/* Capture Area */}
        <div style={{marginBottom:'16px', fontSize:'0.85rem', color:'var(--text-muted)'}}>
          {type === 'invoice' && 'Currency is automatically selected from your profile account.'}
        </div>
        <div style={{marginBottom:'24px', position:'relative'}}>
          {preview ? (
            <div style={{position:'relative', width:'100%', borderRadius:'12px', overflow:'hidden', border:'1px solid var(--border-light)'}}>
              <img src={preview} alt="Receipt" style={{width:'100%', display:'block'}} />
              <button 
                type="button"
                onClick={() => {setFile(null); setPreview(null);}}
                style={{position:'absolute', top:'8px', right:'8px', background:'rgba(0,0,0,0.5)', color:'white', border:'none', borderRadius:'50%', width:'32px', height:'32px', cursor:'pointer'}}
              >
                ✕
              </button>
            </div>
          ) : (
            <div 
              style={{border:'2px dashed var(--border-light)', borderRadius:'12px', padding:'32px 16px', textAlign:'center', cursor:'pointer', background:'rgba(255,255,255,0.02)'}}
              onClick={() => fileInputRef.current?.click()}
            >
              <Camera style={{margin:'0 auto 12px', color:'var(--text-muted)'}} size={32}/>
              <h3 style={{fontSize:'1rem', marginBottom:'4px'}}>Take a Photo</h3>
              <p style={{fontSize:'0.85rem'}}>or upload from gallery</p>
            </div>
          )}
          <input 
            type="file" 
            accept="image/*" 
            capture="environment" 
            ref={fileInputRef}
            onChange={handleCapture}
            style={{display:'none'}}
          />
        </div>

        <div style={{display:'flex', gap:'12px', marginBottom:'16px'}}>
          <div className="form-group" style={{flex:2, marginBottom:0}}>
            <label>Amount</label>
            <input 
              type="number" step="0.01" min="0" required
              className="form-input" 
              placeholder="0.00"
              value={amount} onChange={e=>setAmount(e.target.value)}
            />
          </div>
          {type === 'transaction' && (
            <div className="form-group" style={{flex:1, marginBottom:0}}>
              <label>Currency</label>
              <select required className="form-input" value={currency} onChange={e=>setCurrency(e.target.value)}>
                <option value="">--</option>
                {currencies.map(c => <option key={c.id} value={c.id}>{c.CurrencyCode}</option>)}
              </select>
            </div>
          )}
        </div>

        <div className="form-group">
          <label>Project</label>
          <select required className="form-input" value={project} onChange={e=>setProject(e.target.value)}>
            <option value="">Select a project...</option>
            {projects.map(p => <option key={p.id} value={p.id}>{p.Name}</option>)}
          </select>
        </div>

        {type === 'transaction' && (
          <div className="form-group animate-enter">
            <label>Company Card / Account</label>
            <select required className="form-input" value={account} onChange={e=>setAccount(e.target.value)}>
              <option value="">Select card...</option>
              {accounts.map(a => <option key={a.id} value={a.id}>{a.le_name}: {a.Name}</option>)}
            </select>
          </div>
        )}

        <div className="form-group">
          <label>Description (What & Why)</label>
          <textarea 
            required
            className="form-input" 
            rows="3" 
            placeholder="e.g. Client lunch at..."
            value={desc} onChange={e=>setDesc(e.target.value)}
          ></textarea>
        </div>

        <button type="submit" className="btn" disabled={submitting} style={{marginTop:'12px'}}>
          {submitting ? 'Uploading...' : 'Submit Receipt'}
          {!submitting && <Check size={18}/>}
        </button>

      </form>
    </div>
  )
}

