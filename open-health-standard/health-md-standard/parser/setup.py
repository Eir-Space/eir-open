"""
Health.md Parser - Python library for parsing Health.md files
"""

from setuptools import setup, find_packages

with open("../README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="health-md",
    version="1.0.0",
    author="Birger Moëll",
    author_email="birger.moell@uu.se",
    description="Parser library for Health.md - the open standard for LLM-optimized healthcare data",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/BirgerMoell/health-md-standard",
    project_urls={
        "Bug Tracker": "https://github.com/BirgerMoell/health-md-standard/issues",
        "Documentation": "https://birgermoell.github.io/health-md-standard/",
        "Specification": "https://birgermoell.github.io/health-md-standard/spec.html",
    },
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Healthcare Industry",
        "Intended Audience :: Developers",
        "Intended Audience :: Science/Research",
        "Topic :: Scientific/Engineering :: Medical Science Apps.",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
    ],
    package_dir={"": "."},
    packages=find_packages(),
    python_requires=">=3.8",
    install_requires=[
        "pyyaml>=6.0",
        "markdown>=3.4.0",
        "beautifulsoup4>=4.9.0",
        "python-dateutil>=2.8.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-cov>=4.0.0",
            "black>=22.0.0",
            "flake8>=5.0.0",
            "mypy>=1.0.0",
        ],
        "fhir": [
            "fhir.resources>=7.0.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "health-md=health_md.cli:main",
        ],
    },
    keywords=[
        "healthcare",
        "medical-records",
        "llm",
        "ai",
        "privacy",
        "interoperability",
        "fhir",
        "markdown",
        "health-data",
    ],
)