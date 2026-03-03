import Head from 'next/head'
import Link from 'next/link'

export default function Custom404() {
  return (
    <div className="error-page">
      <Head>
        <title>404 - Page Not Found | EIR Provider Directory</title>
      </Head>
      
      <div className="error-container">
        <div className="error-content">
          <h1 className="error-code">404</h1>
          <h2 className="error-title">Healthcare Provider Not Found</h2>
          <p className="error-description">
            The page you're looking for doesn't exist in our healthcare directory.
          </p>
          
          <div className="error-actions">
            <Link href="/" className="primary-button">
              🏥 Browse All Providers
            </Link>
            
            <Link href="/api/providers" className="secondary-button">
              📊 View API Documentation
            </Link>
          </div>

          <div className="search-suggestion">
            <p>Try searching for:</p>
            <ul>
              <li>🏥 "vårdcentral Stockholm" - Primary care in Stockholm</li>
              <li>👨‍⚕️ "dermatologi" - Skin specialists</li>
              <li>🦷 "tandvård" - Dental care</li>
              <li>✅ "egen remiss" - Self-referral providers</li>
            </ul>
          </div>
        </div>

        <div className="error-stats">
          <h3>Our Healthcare Database</h3>
          <div className="stats-list">
            <div className="stat-item">
              <span className="stat-number">17,000+</span>
              <span className="stat-label">Swedish Healthcare Providers</span>
            </div>
            <div className="stat-item">
              <span className="stat-number">7,500+</span>
              <span className="stat-label">Accept Self-Referrals</span>
            </div>
            <div className="stat-item">
              <span className="stat-number">98%</span>
              <span className="stat-label">Geographic Coverage</span>
            </div>
          </div>
        </div>
      </div>

      <style jsx>{`
        .error-page {
          min-height: 100vh;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          display: flex;
          align-items: center;
          justify-content: center;
          padding: 20px;
        }

        .error-container {
          max-width: 800px;
          width: 100%;
          background: white;
          border-radius: 16px;
          box-shadow: 0 20px 50px rgba(0, 0, 0, 0.1);
          padding: 40px;
          text-align: center;
        }

        .error-code {
          font-size: 6rem;
          font-weight: 700;
          color: #3b82f6;
          margin: 0;
          line-height: 1;
        }

        .error-title {
          font-size: 2rem;
          margin: 16px 0 8px 0;
          color: #1f2937;
        }

        .error-description {
          font-size: 1.1rem;
          color: #6b7280;
          margin-bottom: 32px;
        }

        .error-actions {
          display: flex;
          gap: 16px;
          justify-content: center;
          margin-bottom: 40px;
          flex-wrap: wrap;
        }

        .primary-button, .secondary-button {
          padding: 12px 24px;
          border-radius: 8px;
          font-weight: 500;
          text-decoration: none;
          transition: all 0.2s;
          display: inline-flex;
          align-items: center;
          gap: 8px;
        }

        .primary-button {
          background: #3b82f6;
          color: white;
        }

        .primary-button:hover {
          background: #2563eb;
          transform: translateY(-2px);
        }

        .secondary-button {
          background: #f3f4f6;
          color: #374151;
          border: 1px solid #e5e7eb;
        }

        .secondary-button:hover {
          background: #e5e7eb;
          transform: translateY(-2px);
        }

        .search-suggestion {
          background: #f9fafb;
          border: 1px solid #e5e7eb;
          border-radius: 8px;
          padding: 24px;
          margin-bottom: 32px;
          text-align: left;
        }

        .search-suggestion p {
          font-weight: 500;
          margin-bottom: 12px;
          color: #374151;
        }

        .search-suggestion ul {
          list-style: none;
          margin: 0;
          padding: 0;
        }

        .search-suggestion li {
          padding: 4px 0;
          color: #6b7280;
        }

        .error-stats {
          border-top: 1px solid #e5e7eb;
          padding-top: 32px;
        }

        .error-stats h3 {
          margin-bottom: 20px;
          color: #374151;
        }

        .stats-list {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 20px;
        }

        .stat-item {
          display: flex;
          flex-direction: column;
          align-items: center;
        }

        .stat-number {
          font-size: 2rem;
          font-weight: 700;
          color: #3b82f6;
        }

        .stat-label {
          font-size: 0.9rem;
          color: #6b7280;
          margin-top: 4px;
        }

        @media (max-width: 640px) {
          .error-container {
            padding: 24px;
          }

          .error-code {
            font-size: 4rem;
          }

          .error-title {
            font-size: 1.5rem;
          }

          .error-actions {
            flex-direction: column;
            align-items: center;
          }

          .stats-list {
            grid-template-columns: 1fr;
            gap: 16px;
          }
        }
      `}</style>
    </div>
  )
}