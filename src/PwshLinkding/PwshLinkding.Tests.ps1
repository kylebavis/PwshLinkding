using module '.\PwshLinkding.psm1'

# UPDATE ME: This is just example code. Replace the code below with your module's tests.
Describe 'Get-HelloWorld' {
	It 'Should return "Hello, World!"' {
		$expected = 'Hello, World!'
		$result = $expected
		$result | Should -Be $expected
	}
}
