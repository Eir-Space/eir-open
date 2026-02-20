# Contributing to Health.md

Thank you for your interest in contributing to the Health.md open standard! We welcome contributions from healthcare professionals, developers, researchers, and patients.

## 🎯 How You Can Help

### 🩺 **Healthcare Professionals**
- **Review clinical accuracy** of the specification
- **Propose new sections** for specialty care (cardiology, oncology, etc.)
- **Share workflow insights** from real clinical practice
- **Validate medical terminology** and code usage
- **Test with real (anonymized) data**

### 👩‍💻 **Developers**
- **Improve the parser library** (Python, JavaScript, other languages)
- **Add validation rules** for data consistency
- **Build integrations** with EHR systems
- **Create tools** for format conversion
- **Optimize for LLM consumption**

### 🔬 **Researchers**  
- **Validate the format** with studies and use cases
- **Propose privacy enhancements** based on research
- **Share findings** from Health.md implementations
- **Contribute to academic papers** about the standard

### 👤 **Patients & Advocates**
- **Provide usability feedback** on human readability
- **Share privacy concerns** and requirements
- **Test patient portal integrations**
- **Advocate for adoption** in healthcare systems

## 🚀 Getting Started

### 1. **Understand the Standard**
- Read the [specification](SPEC.md) thoroughly
- Review [examples](examples/) to see Health.md in practice
- Try the [parser library](parser/) with sample files

### 2. **Find Your Area**
- **Documentation:** Improve clarity, add examples, fix typos
- **Specification:** Propose new sections, refine existing ones
- **Parser:** Add features, fix bugs, improve performance  
- **Examples:** Create realistic, diverse sample files
- **Validation:** Build rules for clinical accuracy and privacy
- **Integrations:** Connect with EHRs, FHIR, HL7

### 3. **Check Existing Issues**
- Browse [open issues](https://github.com/BirgerMoell/health-md-standard/issues)
- Look for `good first issue` and `help wanted` labels
- Comment on issues you'd like to work on

## 📋 Contribution Process

### 1. **Fork & Clone**
```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/health-md-standard.git
cd health-md-standard
```

### 2. **Create a Branch**
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-number
```

### 3. **Make Your Changes**
- Follow the [coding standards](#coding-standards) below
- Add tests for new functionality
- Update documentation as needed
- Ensure privacy guidelines are followed

### 4. **Test Your Changes**
```bash
# For parser changes
cd parser
python -m pytest tests/

# For specification changes
# Validate examples against new spec
python validate_examples.py
```

### 5. **Submit a Pull Request**
- Push your branch to your fork
- Create a pull request with:
  - Clear description of changes
  - Reference to related issues
  - Screenshots/examples if applicable
  - Confirmation of testing

## 📏 Standards & Guidelines

### **Specification Changes**
- **Backward compatibility:** Don't break existing Health.md files
- **Clinical accuracy:** Validate with healthcare professionals
- **Privacy-first:** Always consider data protection implications
- **LLM-optimized:** Structure should be easily parsed by AI
- **Version control:** Major changes require version bump

### **Code Standards**
```python
# Python code style
- Use Black formatter: `black .`
- Follow PEP 8 guidelines
- Type hints for all functions
- Docstrings in Google/NumPy format
- 90% test coverage minimum
```

### **Documentation Standards**
- **Clear examples:** Every feature needs a working example
- **Medical accuracy:** Use proper medical terminology
- **Privacy awareness:** Mark sensitive sections appropriately
- **Accessible language:** Write for diverse audiences

### **Example File Standards**
- **Realistic but anonymous:** Based on real patterns, privacy-safe
- **Diverse conditions:** Cover various specialties and demographics
- **Progressive complexity:** Simple to advanced examples
- **Valid format:** Must pass specification validation

## 🔒 Privacy & Security

### **Sensitive Data Handling**
- **Never commit real patient data** to the repository
- **Use synthetic/anonymous data** for all examples
- **Review PRs carefully** for accidental PII inclusion
- **Follow HIPAA/GDPR principles** even for test data

### **Privacy Levels**
When creating examples, use appropriate privacy levels:
- **Anonymous:** No identifiable information
- **Pseudonymized:** Consistent fake identifiers
- **Educational:** Clearly marked synthetic data

## 🧪 Testing Requirements

### **Parser Library Tests**
- Unit tests for all parsing functions
- Integration tests with real Health.md files
- Performance tests with large datasets
- Privacy validation tests

### **Specification Tests**
- Example files validate against specification
- Edge cases are handled properly
- Error messages are helpful
- Cross-platform compatibility

## 📝 Issue Templates

### **Bug Report**
```markdown
**Describe the bug**
A clear description of what the bug is.

**Health.md file (anonymized)**
Attach or paste the problematic file.

**Expected behavior**
What you expected to happen.

**Actual behavior**  
What actually happened.

**Environment**
- health-md version:
- Python version:
- Operating system:
```

### **Feature Request**
```markdown
**Clinical/Technical Context**
Why is this needed? What problem does it solve?

**Proposed Solution**
How should this work?

**Examples**
Show what the Health.md would look like.

**Impact**
Who benefits? How important is this?
```

## 🏆 Recognition

We recognize all contributors in our README and release notes. Significant contributions may be acknowledged in academic papers or conference presentations.

### **Types of Recognition**
- **Specification Contributors:** Listed in SPEC.md
- **Code Contributors:** GitHub contributors list
- **Clinical Reviewers:** Special acknowledgment section
- **Research Collaborators:** Co-authorship opportunities

## 📞 Getting Help

### **Questions & Discussion**
- [GitHub Discussions](https://github.com/BirgerMoell/health-md-standard/discussions) for general questions
- [Issues](https://github.com/BirgerMoell/health-md-standard/issues) for specific bugs/features
- Email: birger.moell@uu.se for sensitive topics

### **Community Guidelines**
- **Be respectful:** Healthcare is personal, discussions should be professional
- **Be patient:** Healthcare moves carefully, and rightly so
- **Be collaborative:** This standard succeeds through diverse input
- **Be privacy-conscious:** Always consider data protection

## 🎯 Current Priorities

### **High Priority (Help Wanted)**
1. **JavaScript parser library** - Expand beyond Python
2. **FHIR integration** - Bidirectional conversion
3. **Clinical validation studies** - Real-world testing
4. **EHR integrations** - Epic, Cerner, Allscripts
5. **Specialty extensions** - Cardiology, oncology, mental health

### **Medium Priority**
1. **Mobile app integration** - iOS/Android examples
2. **Blockchain integration** - For data provenance
3. **Internationalization** - Non-English examples
4. **Academic partnerships** - Research collaborations

---

**Remember:** Healthcare data impacts real people. Every contribution to Health.md helps make healthcare more accessible, understandable, and AI-ready while protecting privacy.

Thank you for helping build the future of healthcare data! 🏥💙